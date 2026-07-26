import Foundation

struct ArtworkSearchSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let source: String
    let imageURL: URL
}

enum ArtworkSearchService {
    static func search(artist: String, album: String?) async throws -> [ArtworkSearchSuggestion] {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtist.isEmpty || !(cleanAlbum?.isEmpty ?? true) else { return [] }

        return try await withThrowingTaskGroup(of: [ArtworkSearchSuggestion].self) { group in
            group.addTask { try await searchITunes(artist: cleanArtist, album: cleanAlbum) }
            group.addTask { try await searchDeezer(artist: cleanArtist, album: cleanAlbum) }
            group.addTask { try await searchCoverArtArchive(artist: cleanArtist, album: cleanAlbum) }

            var combined: [ArtworkSearchSuggestion] = []
            for try await suggestions in group { combined.append(contentsOf: suggestions) }
            var seen = Set<String>()
            return combined.filter { seen.insert($0.imageURL.absoluteString).inserted }
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

    private static func searchITunes(artist: String, album: String?) async throws -> [ArtworkSearchSuggestion] {
        let query = [artist, album].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " ")
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "country", value: "US")
        ]
        let payload: ITunesResponse = try await decode(components.url!)
        return payload.results.compactMap { result in
            guard let rawURL = result.artworkUrl100, let imageURL = URL(string: rawURL.replacingOccurrences(of: "100x100", with: "600x600")) else { return nil }
            return ArtworkSearchSuggestion(
                id: "itunes-(result.collectionId)",
                title: result.collectionName ?? album ?? "Album artwork",
                subtitle: result.artistName ?? artist,
                source: "Apple iTunes",
                imageURL: imageURL
            )
        }
    }

    private static func searchDeezer(artist: String, album: String?) async throws -> [ArtworkSearchSuggestion] {
        let query = [artist, album].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " ")
        var components = URLComponents(string: "https://api.deezer.com/search/album")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        let payload: DeezerResponse = try await decode(components.url!)
        return payload.data.compactMap { result in
            guard let imageURL = URL(string: result.coverXl ?? result.coverBig ?? "") else { return nil }
            return ArtworkSearchSuggestion(
                id: "deezer-(result.id)",
                title: result.title,
                subtitle: result.artist.name,
                source: "Deezer",
                imageURL: imageURL
            )
        }
    }

    private static func searchCoverArtArchive(artist: String, album: String?) async throws -> [ArtworkSearchSuggestion] {
        guard let album, !album.isEmpty else { return [] }
        var components = URLComponents(string: "https://musicbrainz.org/ws/2/release")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "artist:\"\(artist)\" AND release:\"\(album)\""),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "8")
        ]
        let payload: MusicBrainzReleaseResponse = try await decode(components.url!, userAgent: true)
        return payload.releases.compactMap { release in
            guard let imageURL = URL(string: "https://coverartarchive.org/release/\(release.id)/front-500") else { return nil }
            return ArtworkSearchSuggestion(
                id: "coverart-\(release.id)",
                title: release.title,
                subtitle: release.date ?? artist,
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
