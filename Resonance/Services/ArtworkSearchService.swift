import Foundation

struct ArtworkSearchSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let source: String
    let imageURL: URL
    var relevance: Int = 0
}

enum ArtworkSearchService {
    static func search(
        artist: String,
        album: String?,
        albumArtist: String? = nil,
        track: String? = nil
    ) async throws -> [ArtworkSearchSuggestion] {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTrack = track?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtist.isEmpty || !(cleanAlbum?.isEmpty ?? true) else { return [] }

        return try await withThrowingTaskGroup(of: [ArtworkSearchSuggestion].self) { group in
            // A repository outage or rate limit must not hide results returned
            // by the other providers.
            group.addTask {
                (try? await searchITunes(
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum,
                    track: cleanTrack
                )) ?? []
            }
            group.addTask {
                (try? await searchDeezer(
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum,
                    track: cleanTrack
                )) ?? []
            }
            group.addTask {
                (try? await searchCoverArtArchive(
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum
                )) ?? []
            }

            var combined: [ArtworkSearchSuggestion] = []
            for try await suggestions in group { combined.append(contentsOf: suggestions) }
            var seen = Set<String>()
            var unique = combined.filter { seen.insert($0.imageURL.absoluteString).inserted }
            unique = unique.compactMap { suggestion in
                let score = relevance(
                    suggestion,
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum
                )
                guard isCredibleMatch(
                    suggestion,
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum,
                    score: score
                ) else { return nil }
                var suggestion = suggestion
                suggestion.relevance = score
                return suggestion
            }
            return unique.sorted {
                if $0.relevance != $1.relevance { return $0.relevance > $1.relevance }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    static func imageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ArtworkSearchError.invalidResponse
        }
        guard !data.isEmpty else { throw ArtworkSearchError.invalidImage }
        return data
    }

    private static func searchITunes(
        artist: String,
        albumArtist: String?,
        album: String?,
        track: String? = nil
    ) async throws -> [ArtworkSearchSuggestion] {
        let query = queryParts(artist: artist, albumArtist: albumArtist, album: album, track: track).joined(separator: " ")
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "country", value: "US")
        ]
        var payload: ITunesResponse = try await decode(components.url!)
        if payload.results.isEmpty, let album, !album.isEmpty {
            components.queryItems?[0] = URLQueryItem(name: "term", value: album)
            payload = try await decode(components.url!)
        }
        return payload.results.compactMap { result in
            guard let rawURL = result.artworkUrl100, let imageURL = URL(string: rawURL.replacingOccurrences(of: "100x100", with: "600x600")) else { return nil }
            return ArtworkSearchSuggestion(
                id: "itunes-\(result.collectionId)",
                title: result.collectionName ?? album ?? "Album artwork",
                subtitle: result.artistName ?? artist,
                source: "Apple iTunes",
                imageURL: imageURL
            )
        }
    }

    private static func searchDeezer(
        artist: String,
        albumArtist: String?,
        album: String?,
        track: String? = nil
    ) async throws -> [ArtworkSearchSuggestion] {
        let query = queryParts(artist: artist, albumArtist: albumArtist, album: album, track: track).joined(separator: " ")
        var components = URLComponents(string: "https://api.deezer.com/search/album")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        var payload: DeezerResponse = try await decode(components.url!)
        if payload.data.isEmpty, let album, !album.isEmpty {
            components.queryItems?[0] = URLQueryItem(name: "q", value: album)
            payload = try await decode(components.url!)
        }
        return payload.data.compactMap { result in
            guard let imageURL = URL(string: result.coverXl ?? result.coverBig ?? "") else { return nil }
            return ArtworkSearchSuggestion(
                id: "deezer-\(result.id)",
                title: result.title,
                subtitle: result.artist.name,
                source: "Deezer",
                imageURL: imageURL
            )
        }
    }

    private static func searchCoverArtArchive(artist: String, albumArtist: String?, album: String?) async throws -> [ArtworkSearchSuggestion] {
        guard let album, !album.isEmpty else { return [] }
        let releaseArtist = albumArtist?.isEmpty == false ? albumArtist! : artist
        var components = URLComponents(string: "https://musicbrainz.org/ws/2/release")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "artist:\"\(releaseArtist)\" AND release:\"\(album)\""),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "8")
        ]
        let payload: MusicBrainzReleaseResponse = try await decode(components.url!, userAgent: true)
        return payload.releases.compactMap { release in
            guard let imageURL = URL(string: "https://coverartarchive.org/release/\(release.id)/front-500") else { return nil }
            return ArtworkSearchSuggestion(
                id: "coverart-\(release.id)",
                title: release.title,
                subtitle: releaseArtist,
                source: "MusicBrainz Cover Art Archive",
                imageURL: imageURL
            )
        }
    }

    private static func decode<T: Decodable>(_ url: URL, userAgent: Bool = false) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 20)
        if userAgent { request.setValue("Resonance/0.3 artwork lookup (https://github.com/thnikkaman/Resonance)", forHTTPHeaderField: "User-Agent") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ArtworkSearchError.invalidResponse }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func relevance(
        _ suggestion: ArtworkSearchSuggestion,
        artist: String,
        albumArtist: String?,
        album: String?
    ) -> Int {
        let artistKey = normalizedWords(artist)
        let albumArtistKey = normalizedWords(albumArtist ?? "")
        let albumKey = normalizedWords(album ?? "")
        let titleKey = normalizedWords(suggestion.title)
        let subtitleKey = normalizedWords(suggestion.subtitle)
        var score = 0

        if !albumKey.isEmpty {
            if titleKey == albumKey { score += 100 }
            else if titleKey.contains(albumKey) || albumKey.contains(titleKey) { score += 65 }
            score += min(30, albumKey.split(separator: " ").filter { titleKey.contains($0) }.count * 10)
        }
        let artistScore = artistMatchScore(subtitleKey: subtitleKey, artistKey: artistKey)
        let albumArtistScore = artistMatchScore(subtitleKey: subtitleKey, artistKey: albumArtistKey)
        score += max(artistScore, albumArtistScore)

        if !albumArtistKey.isEmpty, albumArtistKey != artistKey, albumArtistScore > 0 {
            score += 20
        }

        switch suggestion.source {
        case "MusicBrainz Cover Art Archive": score += 3
        case "Apple iTunes": score += 2
        default: score += 1
        }
        return score
    }

    private static func isCredibleMatch(
        _ suggestion: ArtworkSearchSuggestion,
        artist: String,
        albumArtist: String?,
        album: String?,
        score: Int
    ) -> Bool {
        let artistKey = normalizedWords(artist)
        let albumArtistKey = normalizedWords(albumArtist ?? "")
        let albumKey = normalizedWords(album ?? "")
        let titleKey = normalizedWords(suggestion.title)
        let subtitleKey = normalizedWords(suggestion.subtitle)
        let artistMatches = artistMatchScore(subtitleKey: subtitleKey, artistKey: artistKey) > 0
            || artistMatchScore(subtitleKey: subtitleKey, artistKey: albumArtistKey) > 0
        let albumMatches = albumKey.isEmpty
            || titleKey == albumKey
            || titleKey.contains(albumKey)
            || albumKey.contains(titleKey)
            || albumKey.split(separator: " ").filter { titleKey.contains($0) }.count >= max(1, albumKey.split(separator: " ").count / 2)

        if albumKey.isEmpty { return artistMatches && score >= 45 }
        return artistMatches && albumMatches && score >= 75
    }

    private static func artistMatchScore(subtitleKey: String, artistKey: String) -> Int {
        guard !artistKey.isEmpty, !subtitleKey.isEmpty else { return 0 }
        if subtitleKey == artistKey { return 80 }
        if subtitleKey.contains(artistKey) || artistKey.contains(subtitleKey) { return 45 }
        let matchedWords = artistKey.split(separator: " ").filter { subtitleKey.contains($0) }.count
        return matchedWords > 0 ? min(20, matchedWords * 10) : 0
    }

    private static func queryParts(artist: String, albumArtist: String?, album: String?, track: String?) -> [String] {
        var result: [String] = []
        for value in [artist, albumArtist, album, track] {
            guard let value, !value.isEmpty,
                  !result.contains(where: { normalizedWords($0) == normalizedWords(value) }) else { continue }
            result.append(value)
        }
        return result
    }

    private static func normalizedWords(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    private struct ITunesResponse: Decodable { let results: [ITunesResult] }
    private struct ITunesResult: Decodable { let collectionId: Int; let collectionName: String?; let artistName: String?; let artworkUrl100: String? }
    private struct DeezerResponse: Decodable { let data: [DeezerResult] }
    private struct DeezerResult: Decodable { let id: Int; let title: String; let coverXl: String?; let coverBig: String?; let artist: DeezerArtist }
    private struct DeezerArtist: Decodable { let name: String }
    private struct MusicBrainzReleaseResponse: Decodable { let releases: [MusicBrainzRelease] }
    private struct MusicBrainzRelease: Decodable { let id: String; let title: String; let date: String? }
}

enum ArtworkSearchError: LocalizedError {
    case invalidResponse
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The artwork service did not return a usable response."
        case .invalidImage: "The selected result was not a valid image."
        }
    }
}

struct StreamingArtworkTrackQuery: Sendable, Hashable {
    let artist: String
    let albumArtist: String?
    let album: String
    let title: String
}

/// Resolves one best artwork candidate for Streaming tiles when the remote
/// catalog has no usable embedded or hosted image. Album artwork is shared by
/// every track in the album, while artist-only lookups are shared by the
/// artist's tiles and detail screens.
actor StreamingArtworkCache {
    static let shared = StreamingArtworkCache()

    private var cachedData: [String: Data] = [:]
    private var misses = Set<String>()
    private var inFlight: [String: Task<Data?, Never>] = [:]

    func seed(
        data: Data,
        artist: String,
        album: String?,
        aliases: [String] = []
    ) {
        guard !data.isEmpty else { return }
        let names = [artist] + aliases
        for name in names {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let artistKey = Self.key(artist: name, album: nil)
            cachedData[artistKey] = data
            misses.remove(artistKey)
            if let album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let albumKey = Self.key(artist: name, album: album)
                cachedData[albumKey] = data
                misses.remove(albumKey)
            }
        }
    }

    func artwork(
        artist: String,
        album: String?,
        trackQueries: [StreamingArtworkTrackQuery] = []
    ) async -> Data? {
        let key = Self.key(artist: artist, album: album)
        guard !key.isEmpty else { return nil }
        if let cached = cachedData[key] { return cached }
        if misses.contains(key) { return nil }
        if let task = inFlight[key] { return await task.value }

        let task = Task<Data?, Never> {
            if let data = await Self.firstUsableImage(
                from: try? await ArtworkSearchService.search(artist: artist, album: album)
            ) {
                return data
            }

            // An artist query can return no usable cover even though one of
            // the artist's albums is indexed with artwork. Try each distinct
            // album represented by the catalog before falling back to songs.
            var searchedAlbums = Set<String>()
            for query in trackQueries {
                let candidateAlbum = album ?? query.album
                if album == nil,
                   !candidateAlbum.isEmpty,
                   searchedAlbums.insert(candidateAlbum).inserted,
                   let data = await Self.firstUsableImage(
                       from: try? await ArtworkSearchService.search(
                           artist: query.artist,
                           album: candidateAlbum,
                           albumArtist: query.albumArtist
                       )
                   ) {
                    return data
                }

                guard !query.title.isEmpty else { continue }
                if let data = await Self.firstUsableImage(
                    from: try? await ArtworkSearchService.search(
                        artist: query.artist,
                        album: album,
                        albumArtist: query.albumArtist,
                        track: query.title
                    )
                ) {
                    return data
                }
            }
            return nil
        }
        inFlight[key] = task
        let data = await task.value
        inFlight[key] = nil

        if let data {
            seed(
                data: data,
                artist: artist,
                album: album,
                aliases: trackQueries.flatMap { [$0.artist, $0.albumArtist ?? ""] }
            )
        } else {
            misses.insert(key)
        }
        return data
    }

    private static func firstUsableImage(from suggestions: [ArtworkSearchSuggestion]?) async -> Data? {
        guard let suggestions else { return nil }
        for suggestion in suggestions.prefix(8) {
            if let data = try? await ArtworkSearchService.imageData(from: suggestion.imageURL) {
                return data
            }
        }
        return nil
    }

    private static func key(artist: String, album: String?) -> String {
        func normalize(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .unicodeScalars
                .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
                .joined()
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
                .lowercased()
        }

        let artistKey = normalize(artist)
        let albumKey = normalize(album ?? "")
        return albumKey.isEmpty ? Self.artistKey(artistKey) : Self.albumKey(artistKey, albumKey)
    }

    private static func artistKey(_ artist: String) -> String {
        "artist|\(artist)"
    }

    private static func albumKey(_ artist: String, _ album: String) -> String {
        "album|\(artist)|\(album)"
    }
}
