import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

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

private actor MusicBrainzRequestLimiter {
    static let shared = MusicBrainzRequestLimiter()
    private var lastRequestDate: Date?

    func waitTurn() async throws {
        if let lastRequestDate {
            let elapsed = Date().timeIntervalSince(lastRequestDate)
            if elapsed < 1 {
                let delay = UInt64((1 - elapsed) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
        lastRequestDate = Date()
    }
}

enum ArtworkSearchService {
    static func search(
        artist: String,
        album: String?,
        albumArtist: String? = nil
    ) async throws -> [ArtworkSearchSuggestion] {
        let report = try await searchReport(
            artist: artist,
            album: album,
            albumArtist: albumArtist
        )
        return report.suggestions
    }

    static func searchReport(
        artist: String,
        album: String?,
        albumArtist: String? = nil
    ) async throws -> ArtworkSearchReport {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtist.isEmpty || !(cleanAlbum?.isEmpty ?? true) else {
            return ArtworkSearchReport(suggestions: [], unavailableProviders: [])
        }

        let providerResult: ProviderSearchResult
        do {
            providerResult = ProviderSearchResult(
                name: "MusicBrainz / Cover Art Archive",
                suggestions: try await searchCoverArtArchive(
                    artist: cleanArtist,
                    albumArtist: cleanAlbumArtist,
                    album: cleanAlbum
                ),
                failed: false
            )
        } catch {
            providerResult = ProviderSearchResult(
                name: "MusicBrainz / Cover Art Archive",
                suggestions: [],
                failed: true
            )
        }

        var seen = Set<String>()
        let unique = providerResult.suggestions
            .filter { seen.insert($0.imageURL.absoluteString).inserted }
            .compactMap { suggestion -> ArtworkSearchSuggestion? in
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
            .sorted {
                if $0.relevance != $1.relevance { return $0.relevance > $1.relevance }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }

        return ArtworkSearchReport(
            suggestions: unique,
            unavailableProviders: providerResult.failed ? [providerResult.name] : []
        )
    }

    static func searchMusicBrainzArchive(query: String) async throws -> [ArtworkSearchSuggestion] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var components = URLComponents(string: "https://musicbrainz.org/ws/2/release-group")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "50")
        ]
        let payload: MusicBrainzReleaseGroupResponse = try await decode(
            components.url!,
            userAgent: true,
            rateLimitedMusicBrainz: true
        )
        let suggestions = await coverArtSuggestions(for: Array(payload.releaseGroups.prefix(25)))
        var seen = Set<String>()
        return suggestions
            .filter { seen.insert($0.imageURL.absoluteString).inserted }
            .sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    static func imageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ArtworkSearchError.invalidResponse
        }
        guard !data.isEmpty else { throw ArtworkSearchError.invalidImage }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ArtworkSearchError.invalidImage
        }
        let normalized = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            normalized as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ArtworkSearchError.invalidImage
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ArtworkSearchError.invalidImage
        }
        return normalized as Data
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
                let payload: MusicBrainzReleaseGroupResponse = try await decode(
                    components.url!,
                    userAgent: true,
                    rateLimitedMusicBrainz: true
                )
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

        let candidateGroups = Array(releaseGroups.prefix(25))
        return await coverArtSuggestions(for: candidateGroups)
    }

    private static func coverArtSuggestions(for releaseGroups: [MusicBrainzReleaseGroup]) async -> [ArtworkSearchSuggestion] {
        var suggestions: [ArtworkSearchSuggestion] = []
        let batchSize = 4
        for batchStart in stride(from: 0, to: releaseGroups.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, releaseGroups.count)
            let batch = releaseGroups[batchStart..<batchEnd]
            let batchSuggestions = await withTaskGroup(of: [ArtworkSearchSuggestion].self) { group in
                for releaseGroup in batch {
                    group.addTask {
                        await coverArtSuggestions(for: releaseGroup)
                    }
                }
                var result: [ArtworkSearchSuggestion] = []
                for await groupResult in group {
                    result.append(contentsOf: groupResult)
                }
                return result
            }
            suggestions.append(contentsOf: batchSuggestions)
        }
        return suggestions
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

    private static func decode<T: Decodable>(
        _ url: URL,
        userAgent: Bool = false,
        rateLimitedMusicBrainz: Bool = false
    ) async throws -> T {
        if rateLimitedMusicBrainz {
            try await MusicBrainzRequestLimiter.shared.waitTurn()
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        if userAgent {
            request.setValue(
                "MeiKyo/1.0 (https://github.com/thnikkaman/Resonance)",
                forHTTPHeaderField: "User-Agent"
            )
        }
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
        for albumVariant in albumTitleVariants(album) {
            if !artistCandidates.isEmpty {
                let artistClauses = artistCandidates.map { "artist:\"\(musicBrainzLiteral($0))\"" }.joined(separator: " OR ")
                let artistQuery = artistCandidates.count > 1 ? "(\(artistClauses))" : artistClauses
                queries.append("\(artistQuery) AND releasegroup:\"\(musicBrainzLiteral(albumVariant))\"")
            }
            queries.append("releasegroup:\"\(musicBrainzLiteral(albumVariant))\"")
        }
        return queries.reduce(into: [String]()) { result, query in
            if !result.contains(query) { result.append(query) }
        }
    }

    private static func albumTitleVariants(_ album: String?) -> [String] {
        guard let album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var variants = [album.trimmingCharacters(in: .whitespacesAndNewlines)]
        var current = variants[0]
        while let stripped = stripTrailingReleaseMetadata(from: current), stripped != current {
            current = stripped
            if !variants.contains(where: { normalizedWords($0) == normalizedWords(current) }) {
                variants.append(current)
            }
        }
        return variants
    }

    private static func stripTrailingReleaseMetadata(from value: String) -> String? {
        var working = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let bracketPattern = #"\s*[\(\[\{][^\)\]\}]+[\)\]\}]\s*$"#
        if let expression = try? NSRegularExpression(pattern: bracketPattern),
           let match = expression.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)) {
            let suffix = String(working[Range(match.range, in: working)!])
            if containsReleaseMetadataMarker(suffix) {
                working.removeSubrange(Range(match.range, in: working)!)
                return working.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var words = working.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var removed = false
        while let last = words.last {
            let normalized = normalizedWords(last)
            let isYear = normalized.count == 4 && normalized.allSatisfy(\.isNumber)
            if removed || isYear || containsReleaseMetadataMarker(normalized) {
                words.removeLast()
                removed = true
            } else {
                break
            }
        }
        guard removed else { return nil }
        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsReleaseMetadataMarker(_ value: String) -> Bool {
        let normalized = normalizedWords(value)
        let markers = [
            "anniversary", "audiophile", "bit", "bits", "deluxe", "digital", "edition",
            "expanded", "flac", "high resolution", "hi res", "hires", "japanese", "lossless",
            "master", "remaster", "remastered", "special", "stereo", "vinyl", "wav"
        ]
        return markers.contains(where: { normalized == $0 || normalized.contains(" \($0) ") || normalized.hasPrefix("\($0) ") || normalized.hasSuffix(" \($0)") })
            || normalized.split(separator: " ").contains(where: { $0 == "bit" || $0 == "bits" })
    }

    private static func musicBrainzLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
    private var cacheAccessOrder: [String: UInt64] = [:]
    private var cacheAccessCounter: UInt64 = 0
    private var cachedDataBytes = 0
    private let maximumCachedEntries = 256
    private let maximumCachedBytes = 32 * 1_048_576
    private var misses = Set<String>()
    private var inFlight: [String: Task<Data?, Never>] = [:]
    private let diskDirectory: URL

    init() {
        diskDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ResonanceStreamingArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    func seed(
        data: Data,
        artist: String,
        album: String?,
        aliases: [String] = []
    ) {
        guard !data.isEmpty else { return }
        // Album artwork must not become an artist-wide result. A compilation
        // or mixed-artist album can contain many unrelated artists, and
        // seeding those aliases would make the first successful cover appear
        // on every artist tile. Artist aliases are safe only for an
        // artist-level lookup and only when they normalize to the same name.
        let names: [String]
        if album == nil {
            let normalizedArtist = Self.normalize(artist)
            names = [artist] + aliases.filter { Self.normalize($0) == normalizedArtist }
        } else {
            names = [artist]
        }
        for name in names {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let artistKey = Self.key(artist: name, album: nil)
            cache(data, for: artistKey)
            persist(data, for: artistKey)
            misses.remove(artistKey)
            if let album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let albumKey = Self.key(artist: name, album: album)
                cache(data, for: albumKey)
                persist(data, for: albumKey)
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
        if let cached = cachedData[key] {
            touch(key)
            return cached
        }
        if let cached = loadPersistedData(for: key) {
            cache(cached, for: key)
            return cached
        }
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
            let relevantQueries: [StreamingArtworkTrackQuery]
            if album == nil {
                let requestedArtist = Self.normalize(artist)
                relevantQueries = trackQueries.filter {
                    Self.normalize($0.artist) == requestedArtist ||
                    Self.normalize($0.albumArtist ?? "") == requestedArtist
                }
            } else {
                relevantQueries = trackQueries
            }
            for query in relevantQueries {
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
                        albumArtist: query.albumArtist
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
            persist(data, for: key)
        } else {
            misses.insert(key)
        }
        return data
    }

    private func persist(_ data: Data, for key: String) {
        let destination = diskURL(for: key)
        try? data.write(to: destination, options: .atomic)
    }

    private func cache(_ data: Data, for key: String) {
        guard !data.isEmpty else { return }
        if let previous = cachedData[key] {
            cachedDataBytes -= previous.count
        }
        cachedData[key] = data
        cachedDataBytes += data.count
        touch(key)

        while cachedData.count > maximumCachedEntries || cachedDataBytes > maximumCachedBytes {
            guard let victim = cacheAccessOrder.min(by: { $0.value < $1.value })?.key else { break }
            guard let removed = cachedData.removeValue(forKey: victim) else {
                cacheAccessOrder.removeValue(forKey: victim)
                continue
            }
            cachedDataBytes -= removed.count
            cacheAccessOrder.removeValue(forKey: victim)
        }
    }

    private func touch(_ key: String) {
        cacheAccessCounter &+= 1
        cacheAccessOrder[key] = cacheAccessCounter
    }

    private func loadPersistedData(for key: String) -> Data? {
        let destination = diskURL(for: key)
        guard let data = try? Data(contentsOf: destination), !data.isEmpty else { return nil }
        return data
    }

    private func diskURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return diskDirectory.appendingPathComponent(digest).appendingPathExtension("artwork")
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
        let artistKey = normalize(artist)
        let albumKey = normalize(album ?? "")
        return albumKey.isEmpty ? Self.artistKey(artistKey) : Self.albumKey(artistKey, albumKey)
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    private static func artistKey(_ artist: String) -> String {
        "artist|\(artist)"
    }

    private static func albumKey(_ artist: String, _ album: String) -> String {
        "album|\(artist)|\(album)"
    }
}
