import Foundation

struct ArtworkSearchSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let source: String
    let imageURL: URL
    var relevance: Int = 0
}

struct ArtworkSearchReport: Sendable {
    let suggestions: [ArtworkSearchSuggestion]
    let unavailableProviders: [String]
}

enum ArtworkSearchService {
    static func search(
        artist: String,
        album: String?,
        albumArtist: String? = nil,
        track: String? = nil
    ) async throws -> [ArtworkSearchSuggestion] {
        let report = try await searchReport(
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            track: track
        )
        return report.suggestions
    }

    static func searchReport(
        artist: String,
        album: String?,
        albumArtist: String? = nil,
        track: String? = nil
    ) async throws -> ArtworkSearchReport {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTrack = track?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtist.isEmpty || !(cleanAlbum?.isEmpty ?? true) else {
            return ArtworkSearchReport(suggestions: [], unavailableProviders: [])
        }

        return await withTaskGroup(of: ProviderSearchResult.self) { group in
            group.addTask {
                do {
                    return ProviderSearchResult(
                        name: "Apple iTunes",
                        suggestions: try await searchITunes(
                            artist: cleanArtist,
                            albumArtist: cleanAlbumArtist,
                            album: cleanAlbum,
                            track: cleanTrack
                        ),
                        failed: false
                    )
                } catch {
                    return ProviderSearchResult(name: "Apple iTunes", suggestions: [], failed: true)
                }
            }
            group.addTask {
                do {
                    return ProviderSearchResult(
                        name: "MusicBrainz / Cover Art Archive",
                        suggestions: try await searchCoverArtArchive(
                            artist: cleanArtist,
                            albumArtist: cleanAlbumArtist,
                            album: cleanAlbum
                        ),
                        failed: false
                    )
                } catch {
                    return ProviderSearchResult(name: "MusicBrainz / Cover Art Archive", suggestions: [], failed: true)
                }
            }

            var providerResults: [ProviderSearchResult] = []
            for await result in group { providerResults.append(result) }

            var combined: [ArtworkSearchSuggestion] = []
            for result in providerResults { combined.append(contentsOf: result.suggestions) }
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
            unique.sort {
                if $0.relevance != $1.relevance { return $0.relevance > $1.relevance }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return ArtworkSearchReport(
                suggestions: unique,
                unavailableProviders: providerResults.filter(\.failed).map(\.name).sorted()
            )
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
        let queries = searchQueries(artist: artist, albumArtist: albumArtist, album: album, track: track)
        guard !queries.isEmpty else { return [] }

        var results: [ITunesResult] = []
        var seenCollectionIDs = Set<Int>()
        var firstError: Error?
        for query in queries {
            var components = URLComponents(string: "https://itunes.apple.com/search")!
            components.queryItems = [
                URLQueryItem(name: "term", value: query),
                URLQueryItem(name: "entity", value: "album"),
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "country", value: "US")
            ]
            do {
                let payload: ITunesResponse = try await decode(components.url!)
                for result in payload.results where seenCollectionIDs.insert(result.collectionId).inserted {
                    results.append(result)
                }
            } catch {
                firstError = firstError ?? error
            }
        }
        if results.isEmpty, let firstError {
            throw firstError
        }
        return results.compactMap { result in
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

    private static func searchCoverArtArchive(artist: String, albumArtist: String?, album: String?) async throws -> [ArtworkSearchSuggestion] {
        guard let album, !album.isEmpty else { return [] }
        let artistCandidates = uniqueIdentityValues([albumArtist, artist])
        let queries = musicBrainzQueries(artistCandidates: artistCandidates, album: album)
        guard !queries.isEmpty else { return [] }

        var releaseGroups: [MusicBrainzReleaseGroup] = []
        var seenReleaseGroupIDs = Set<String>()
        var firstError: Error?
        for query in queries {
            var components = URLComponents(string: "https://musicbrainz.org/ws/2/release-group")!
            components.queryItems = [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "fmt", value: "json"),
                URLQueryItem(name: "limit", value: "50")
            ]
            do {
                let payload: MusicBrainzReleaseGroupResponse = try await decode(components.url!, userAgent: true)
                for releaseGroup in payload.releaseGroups where seenReleaseGroupIDs.insert(releaseGroup.id).inserted {
                    releaseGroups.append(releaseGroup)
                }
            } catch {
                firstError = firstError ?? error
            }
        }
        if releaseGroups.isEmpty, let firstError {
            throw firstError
        }

        return await withTaskGroup(of: [ArtworkSearchSuggestion].self) { group in
            for releaseGroup in releaseGroups.prefix(25) {
                group.addTask {
                    await coverArtSuggestions(for: releaseGroup)
                }
            }
            var suggestions: [ArtworkSearchSuggestion] = []
            for await result in group { suggestions.append(contentsOf: result) }
            return suggestions
        }
    }

    private static func coverArtSuggestions(for releaseGroup: MusicBrainzReleaseGroup) async -> [ArtworkSearchSuggestion] {
        guard let url = URL(string: "https://coverartarchive.org/release-group/\(releaseGroup.id)") else { return [] }
        do {
            let payload: CoverArtArchiveResponse = try await decode(url, userAgent: true)
            let creditedArtist = releaseGroup.artistCredit?.map(\.name).joined(separator: " & ") ?? ""
            return payload.images.filter(\.front).compactMap { image in
                let rawURL = image.thumbnails?["500"] ?? image.thumbnails?["large"] ?? image.image
                guard let rawURL,
                      let imageURL = URL(string: rawURL.replacingOccurrences(of: "http://", with: "https://")) else { return nil }
                return ArtworkSearchSuggestion(
                    id: "coverart-group-\(releaseGroup.id)-\(image.id)",
                    title: releaseGroup.title,
                    subtitle: creditedArtist,
                    source: "MusicBrainz Cover Art Archive",
                    imageURL: imageURL
                )
            }
        } catch {
            return []
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
        let artistMatches = (artistKey.isEmpty && albumArtistKey.isEmpty)
            || artistMatchScore(subtitleKey: subtitleKey, artistKey: artistKey) > 0
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

    private static func searchQueries(artist: String, albumArtist: String?, album: String?, track: String?) -> [String] {
        var result: [String] = []
        if let album, !album.isEmpty { result.append(album) }
        let combined = queryParts(artist: artist, albumArtist: albumArtist, album: album, track: track).joined(separator: " ")
        if !combined.isEmpty,
           !result.contains(where: { normalizedWords($0) == normalizedWords(combined) }) {
            result.append(combined)
        }
        return result
    }

    private static func uniqueIdentityValues(_ values: [String?]) -> [String] {
        var result: [String] = []
        for value in values {
            guard let value, !value.isEmpty,
                  !result.contains(where: { normalizedWords($0) == normalizedWords(value) }) else { continue }
            result.append(value)
        }
        return result
    }

    private static func musicBrainzQueries(artistCandidates: [String], album: String) -> [String] {
        var queries: [String] = []
        if !artistCandidates.isEmpty {
            let artistClauses = artistCandidates.map { "artist:\"\($0)\"" }.joined(separator: " OR ")
            let artistQuery = artistCandidates.count > 1 ? "(\(artistClauses))" : artistClauses
            queries.append("\(artistQuery) AND releasegroup:\"\(album)\"")
        }
        queries.append("releasegroup:\"\(album)\"")
        return queries
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
    private struct MusicBrainzReleaseGroupResponse: Decodable {
        let releaseGroups: [MusicBrainzReleaseGroup]

        enum CodingKeys: String, CodingKey {
            case releaseGroups = "release-groups"
        }
    }
    private struct MusicBrainzReleaseGroup: Decodable, Sendable {
        let id: String
        let title: String
        let score: Int?
        let artistCredit: [MusicBrainzArtistCredit]?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case score
            case artistCredit = "artist-credit"
        }
    }
    private struct MusicBrainzArtistCredit: Decodable, Sendable { let name: String }
    private struct CoverArtArchiveResponse: Decodable, Sendable { let images: [CoverArtArchiveImage] }
    private struct CoverArtArchiveImage: Decodable, Sendable {
        let id: Int
        let front: Bool
        let image: String?
        let thumbnails: [String: String]?
    }
    private struct ProviderSearchResult: Sendable {
        let name: String
        let suggestions: [ArtworkSearchSuggestion]
        let failed: Bool
    }
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
        for suggestion in suggestions.prefix(24) {
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
