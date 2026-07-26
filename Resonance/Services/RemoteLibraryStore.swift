import Foundation
import CryptoKit

struct RemoteLibraryManifest: Decodable, Sendable {
    let version: Int?
    let name: String?
    let tracks: [RemoteTrackRecord]
}

struct RemoteTrackRecord: Decodable, Sendable {
    let id: String?
    let title: String
    let artist: String
    let albumArtist: String?
    let album: String
    let trackNumber: Int?
    let discNumber: Int?
    let releaseYear: Int?
    let duration: Double?
    let fileSize: Int64?
    let path: String
    let artwork: String?
    let artworkBase64: String?
}

struct RemoteTrackItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let sourceID: String?
    let title: String
    let artist: String
    let albumArtist: String
    let album: String
    let trackNumber: Int
    let discNumber: Int
    let releaseYear: Int
    let duration: Double
    let fileSizeBytes: Int64
    let streamURL: URL
    let artworkURL: URL?
    let artworkBase64: String?
    let coverArtID: String?
    let starred: Bool?
    let dateAdded: Date?
    let lastPlayed: Date?

    var isFavorite: Bool { starred == true }
    var albumKey: String { "\(resonanceNormalizedRemoteKey(albumArtist))|\(resonanceNormalizedRemoteKey(album))" }

    func asTrack(artworkData: Data?) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            releaseYear: releaseYear,
            duration: duration,
            fileURL: streamURL,
            artworkData: artworkData,
            artworkIsEmbedded: artworkData != nil,
            dateAdded: .distantPast,
            sourceByteSize: fileSizeBytes
        )
    }

    func settingStarred(_ value: Bool) -> RemoteTrackItem {
        RemoteTrackItem(
            id: id,
            sourceID: sourceID,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            releaseYear: releaseYear,
            duration: duration,
            fileSizeBytes: fileSizeBytes,
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: artworkBase64,
            coverArtID: coverArtID,
            starred: value,
            dateAdded: dateAdded,
            lastPlayed: lastPlayed
        )
    }

    func settingLastPlayed(_ date: Date) -> RemoteTrackItem {
        RemoteTrackItem(
            id: id,
            sourceID: sourceID,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            releaseYear: releaseYear,
            duration: duration,
            fileSizeBytes: fileSizeBytes,
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: artworkBase64,
            coverArtID: coverArtID,
            starred: starred,
            dateAdded: dateAdded,
            lastPlayed: date
        )
    }

    func settingAlbumArtist(_ value: String) -> RemoteTrackItem {
        RemoteTrackItem(
            id: id,
            sourceID: sourceID,
            title: title,
            artist: artist,
            albumArtist: value,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            releaseYear: releaseYear,
            duration: duration,
            fileSizeBytes: fileSizeBytes,
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: artworkBase64,
            coverArtID: coverArtID,
            starred: starred,
            dateAdded: dateAdded,
            lastPlayed: lastPlayed
        )
    }
}

struct RemoteAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let tracks: [RemoteTrackItem]

    var artworkURL: URL? { tracks.compactMap(\.artworkURL).first }
    var artworkBase64: String? { tracks.compactMap(\.artworkBase64).first }
    var releaseYear: Int { tracks.map(\.releaseYear).filter { $0 > 0 }.min() ?? 0 }
}

struct RemoteArtist: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let albums: [RemoteAlbum]

    var artworkURL: URL? { albums.compactMap(\.artworkURL).first }
    var artworkBase64: String? { albums.compactMap(\.artworkBase64).first }
    var tracks: [RemoteTrackItem] { albums.flatMap(\.tracks) }
}

struct RemotePlaylist: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let owner: String?
    let tracks: [RemoteTrackItem]

    var artworkURL: URL? { tracks.compactMap(\.artworkURL).first }
    var artworkBase64: String? { tracks.compactMap(\.artworkBase64).first }
    var duration: Double { tracks.reduce(0) { $0 + max(0, $1.duration) } }
}

private struct CachedRemoteTrack: Codable, Sendable {
    let id: UUID
    let sourceID: String
    let title: String
    let artist: String
    let albumArtist: String
    let album: String
    let trackNumber: Int
    let discNumber: Int
    let releaseYear: Int
    let duration: Double
    let fileSizeBytes: Int64
    let coverArtID: String?
    let starred: Bool?
    let dateAdded: Date?
    let lastPlayed: Date?

    init?(_ track: RemoteTrackItem) {
        guard let sourceID = track.sourceID?.nonEmpty else { return nil }
        self.id = track.id
        self.sourceID = sourceID
        self.title = track.title
        self.artist = track.artist
        self.albumArtist = track.albumArtist
        self.album = track.album
        self.trackNumber = track.trackNumber
        self.discNumber = track.discNumber
        self.releaseYear = track.releaseYear
        self.duration = track.duration
        self.fileSizeBytes = track.fileSizeBytes
        self.coverArtID = track.coverArtID
        self.starred = track.starred
        self.dateAdded = track.dateAdded
        self.lastPlayed = track.lastPlayed
    }
}

private struct CachedRemoteCatalog: Codable, Sendable {
    let serverName: String
    let savedAt: Date
    let albumFingerprint: String
    let tracks: [CachedRemoteTrack]
}

enum RemoteBrowseGrouping: String, CaseIterable, Identifiable {
    case artists = "Artists"
    case albumArtists = "Album Artists"
    case albums = "Albums"
    case songs = "Songs"
    case favorites = "Favorites"
    case recentlyAdded = "Recently Added"
    case recentlyPlayed = "Recently Played"
    var id: String { rawValue }
}

@MainActor
final class RemoteLibraryStore: ObservableObject {
    @Published private(set) var tracks: [RemoteTrackItem] = [] {
        didSet {
            trackRevision &+= 1
            browseCache = nil
        }
    }
    @Published private(set) var serverName = "Remote Library"
    @Published private(set) var connectionStatus = "Not connected"
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var playlists: [RemotePlaylist] = []
    @Published private(set) var catalogSyncStatus = "No cached remote catalog"
    @Published private(set) var lastCatalogCheck: Date?
    @Published var playlistSearchText = ""
    @Published var grouping: RemoteBrowseGrouping = .artists
    @Published var sortDirection: SortDirection = .ascending {
        didSet { browseCache = nil }
    }

    var hasConnectionIssue: Bool {
        guard !isLoading else { return false }
        let combined = "\(connectionStatus) \(catalogSyncStatus)".lowercased()
        return ["not connected", "failed", "error", "offline", "could not", "unable", "invalid", "denied", "no cached"]
            .contains { combined.contains($0) }
    }

    private let artworkCache = NSCache<NSURL, NSData>()
    private var pendingSubsonicCache: CachedRemoteCatalog?
    private var lastAutomaticCatalogCheck: Date?
    private var playbackPreparationGeneration = 0
    private static let cachedTracksURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("remote-library-cache.json")
    }()
    private static let cachedSubsonicCatalogURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("remote-subsonic-catalog.json")
    }()

    private struct BrowseCacheKey: Equatable {
        let trackRevision: Int
        let sortDirection: String
        let groupCompilationArtists: Bool
    }

    private enum BrowseNeed: Equatable {
        case filtered
        case albums
        case artists
        case albumArtists
    }

    private struct BrowseCache {
        let key: BrowseCacheKey
        let filteredTracks: [RemoteTrackItem]
        var albums: [RemoteAlbum]?
        var artists: [RemoteArtist]?
        var albumArtists: [RemoteArtist]?

        func contains(_ need: BrowseNeed) -> Bool {
            switch need {
            case .filtered: true
            case .albums: albums != nil
            case .artists: artists != nil
            case .albumArtists: albumArtists != nil
            }
        }
    }

    private var trackRevision = 0
    private var browseCache: BrowseCache?

    init() {
        if let data = try? Data(contentsOf: Self.cachedSubsonicCatalogURL),
           let cached = try? JSONDecoder().decode(CachedRemoteCatalog.self, from: data) {
            pendingSubsonicCache = cached
            serverName = cached.serverName
            lastRefresh = cached.savedAt
            connectionStatus = "Cached Navidrome catalog ready"
            catalogSyncStatus = "Cached catalog: \(cached.tracks.count) tracks"
        } else if let data = try? Data(contentsOf: Self.cachedTracksURL),
                  let cached = try? JSONDecoder().decode([RemoteTrackItem].self, from: data) {
            tracks = cached
            connectionStatus = cached.isEmpty ? "Not connected" : "Cached manifest library available"
            catalogSyncStatus = cached.isEmpty ? "No cached remote catalog" : "Cached manifest: \(cached.count) tracks"
        }
    }

    var filteredTracks: [RemoteTrackItem] { browseData(need: .filtered).filteredTracks }

    var albums: [RemoteAlbum] { browseData(need: .albums).albums ?? [] }

    var artists: [RemoteArtist] { browseData(groupCompilationArtists: false, need: .artists).artists ?? [] }
    var albumArtists: [RemoteArtist] { browseData(groupCompilationArtists: false, need: .albumArtists).albumArtists ?? [] }

    func artists(groupCompilationArtists: Bool) -> [RemoteArtist] {
        browseData(groupCompilationArtists: groupCompilationArtists, need: .artists).artists ?? []
    }

    func albumArtists(groupCompilationArtists: Bool) -> [RemoteArtist] {
        browseData(groupCompilationArtists: groupCompilationArtists, need: .albumArtists).albumArtists ?? []
    }

    private func browseData(
        groupCompilationArtists: Bool = false,
        need: BrowseNeed
    ) -> BrowseCache {
        let key = BrowseCacheKey(
            trackRevision: trackRevision,
            sortDirection: sortDirection.rawValue,
            groupCompilationArtists: groupCompilationArtists
        )

        if var browseCache, browseCache.key == key {
            guard !browseCache.contains(need) else { return browseCache }
            populate(&browseCache, need: need)
            self.browseCache = browseCache
            return browseCache
        }

        let input = tracks
        let sorted = input.sorted {
            ($0.artist, $0.album, $0.discNumber, $0.trackNumber, $0.title) <
            ($1.artist, $1.album, $1.discNumber, $1.trackNumber, $1.title)
        }
        let filtered = sortDirection == .ascending ? sorted : Array(sorted.reversed())
        var cache = BrowseCache(
            key: key,
            filteredTracks: filtered,
            albums: nil,
            artists: nil,
            albumArtists: nil
        )
        populate(&cache, need: need)
        browseCache = cache
        return cache
    }

    private func populate(_ cache: inout BrowseCache, need: BrowseNeed) {
        guard !cache.contains(need) else { return }
        switch need {
        case .filtered:
            break
        case .albums:
            cache.albums = makeAlbums(from: cache.filteredTracks)
        case .artists, .albumArtists:
            let compilationAlbumKeys = cache.key.groupCompilationArtists
                ? Self.compilationAlbumKeys(in: tracks)
                : Set<String>()
            let artists = remoteArtists(
                usingAlbumArtist: need == .albumArtists,
                from: cache.filteredTracks,
                compilationAlbumKeys: compilationAlbumKeys
            )
            if need == .artists {
                cache.artists = artists
            } else {
                cache.albumArtists = artists
            }
        }
    }

    private func makeAlbums(from filteredTracks: [RemoteTrackItem]) -> [RemoteAlbum] {
        let grouped = Dictionary(grouping: filteredTracks, by: \.albumKey)
        let result = grouped.compactMap { key, values -> RemoteAlbum? in
            let unique = Self.uniqueTracks(values)
            let sorted = unique.sorted {
                ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title)
            }
            guard let first = sorted.first else { return nil }
            let artistName = Self.preferredDisplayName(sorted.map(\.albumArtist), fallback: first.albumArtist)
            let albumName = Self.preferredDisplayName(sorted.map(\.album), fallback: first.album)
            return RemoteAlbum(id: key, title: albumName, artist: artistName, tracks: sorted)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return sortDirection == .ascending ? result : Array(result.reversed())
    }

    var filteredPlaylists: [RemotePlaylist] {
        let input = playlistSearchText.isEmpty ? playlists : playlists.filter {
            $0.name.localizedCaseInsensitiveContains(playlistSearchText)
            || $0.tracks.contains {
                [$0.title, $0.artist, $0.albumArtist, $0.album]
                    .contains { $0.localizedCaseInsensitiveContains(playlistSearchText) }
            }
        }
        return input.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var favoriteTracks: [RemoteTrackItem] {
        filteredTracks.filter(\.isFavorite)
    }

    var recentlyAddedTracks: [RemoteTrackItem] {
        filteredTracks
            .filter { $0.dateAdded != nil }
            .sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
    }

    var recentlyPlayedTracks: [RemoteTrackItem] {
        filteredTracks
            .filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    private func remoteArtists(
        usingAlbumArtist: Bool,
        from filteredTracks: [RemoteTrackItem],
        compilationAlbumKeys: Set<String>
    ) -> [RemoteArtist] {
        let sourceTracks = Self.uniqueTracks(filteredTracks)
        var grouped = Dictionary(grouping: sourceTracks) { track in
            let sourceName = usingAlbumArtist ? track.albumArtist : track.artist
            return resonanceNormalizedRemoteKey(sourceName)
        }

        if !compilationAlbumKeys.isEmpty {
            var variousTracks: [RemoteTrackItem] = []
            for key in Array(grouped.keys) {
                guard let values = grouped[key] else { continue }
                let regularTracks = values.filter {
                    !compilationAlbumKeys.contains(Self.compilationAlbumIdentity($0))
                }
                variousTracks.append(contentsOf: values.filter {
                    compilationAlbumKeys.contains(Self.compilationAlbumIdentity($0))
                })
                if regularTracks.isEmpty {
                    grouped.removeValue(forKey: key)
                } else {
                    grouped[key] = regularTracks
                }
            }
            if !variousTracks.isEmpty {
                grouped[resonanceNormalizedRemoteKey("Various Artists")] = variousTracks
            }
        }

        let rawArtists = grouped.compactMap { key, values -> RemoteArtist? in
            let unique = Self.uniqueTracks(values)
            guard !unique.isEmpty else { return nil }
            let names = unique.map { usingAlbumArtist ? $0.albumArtist : $0.artist }
            let displayName = key == resonanceNormalizedRemoteKey("Various Artists")
                ? "Various Artists"
                : Self.preferredDisplayName(names, fallback: names.first ?? "Unknown Artist")
            let albumGroupingKey: (RemoteTrackItem) -> String = { track in
                if compilationAlbumKeys.contains(Self.compilationAlbumIdentity(track)) {
                    return Self.compilationAlbumIdentity(track)
                }
                return usingAlbumArtist ? track.albumKey : resonanceNormalizedRemoteKey(track.album)
            }
            let artistAlbums = Dictionary(grouping: unique) { track in
                albumGroupingKey(track)
            }.compactMap { albumKey, albumTracks -> RemoteAlbum? in
                let sorted = Self.uniqueTracks(albumTracks).sorted {
                    ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title)
                }
                guard let first = sorted.first else { return nil }
                return RemoteAlbum(
                    id: "\(key)|\(albumKey)",
                    title: Self.preferredDisplayName(sorted.map(\.album), fallback: first.album),
                    artist: displayName,
                    tracks: sorted
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return RemoteArtist(id: "\(usingAlbumArtist ? "album" : "track")|\(key)", name: displayName, albums: artistAlbums)
        }

        // Final display-name merge guarantees that visually identical artist
        // names appear once even if a server exposes inconsistent tag sources.
        let merged = Dictionary(grouping: rawArtists) { resonanceNormalizedRemoteKey($0.name) }
            .compactMap { key, artists -> RemoteArtist? in
                let allTracks = Self.uniqueTracks(artists.flatMap(\.tracks))
                guard !allTracks.isEmpty else { return nil }
                let name = Self.preferredDisplayName(artists.map(\.name), fallback: artists[0].name)
                let albums = Dictionary(grouping: allTracks) { track in
                    if compilationAlbumKeys.contains(Self.compilationAlbumIdentity(track)) {
                        return Self.compilationAlbumIdentity(track)
                    }
                    return usingAlbumArtist ? track.albumKey : resonanceNormalizedRemoteKey(track.album)
                }.compactMap { albumKey, albumTracks -> RemoteAlbum? in
                    let sorted = Self.uniqueTracks(albumTracks).sorted {
                        ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title)
                    }
                    guard let first = sorted.first else { return nil }
                    return RemoteAlbum(
                        id: "merged|\(key)|\(albumKey)",
                        title: Self.preferredDisplayName(sorted.map(\.album), fallback: first.album),
                        artist: name,
                        tracks: sorted
                    )
                }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                return RemoteArtist(id: "merged|\(usingAlbumArtist ? "album" : "track")|\(key)", name: name, albums: albums)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return sortDirection == .ascending ? merged : Array(merged.reversed())
    }

    nonisolated private static func compilationAlbumIdentity(_ track: RemoteTrackItem) -> String {
        // albumKey includes albumArtist. Compilation tags often vary that field
        // from track to track, so using albumKey would split one compilation
        // before it can be recognized and grouped.
        [
            resonanceNormalizedRemoteKey(track.album),
            track.releaseYear > 0 ? String(track.releaseYear) : ""
        ].joined(separator: "|")
    }

    nonisolated private static func compilationAlbumKeys(in tracks: [RemoteTrackItem]) -> Set<String> {
        Dictionary(grouping: tracks, by: compilationAlbumIdentity).compactMap { key, albumTracks in
            isVariousArtistsAlbum(albumTracks) ? key : nil
        }.reduce(into: Set<String>()) { result, key in
            result.insert(key)
        }
    }

    nonisolated private static func isVariousArtistsAlbum(_ tracks: [RemoteTrackItem]) -> Bool {
        let albumArtistKeys = Set(
            tracks.map { resonanceNormalizedRemoteKey($0.albumArtist) }
                .filter { !$0.isEmpty }
        )
        if albumArtistKeys.contains(where: isVariousArtistsLabel) { return true }

        let trackArtistKeys = Set(
            tracks.map { resonanceNormalizedRemoteKey($0.artist) }
                .filter { !$0.isEmpty }
        )
        guard trackArtistKeys.count > 1 else { return false }
        // Multiple album-artist values on the same normalized album are a
        // common Navidrome representation of a compilation.
        if albumArtistKeys.count > 1 { return true }
        guard let albumArtistKey = albumArtistKeys.first else { return true }
        return !trackArtistKeys.contains(albumArtistKey)
    }

    nonisolated private static func isVariousArtistsLabel(_ value: String) -> Bool {
        ["various artists", "various artist", "various", "va"].contains(value)
    }

    nonisolated fileprivate static func uniqueTracks(_ values: [RemoteTrackItem]) -> [RemoteTrackItem] {
        var seenSourceIDs = Set<String>()
        var seenUUIDs = Set<UUID>()
        return values.filter { track in
            if let sourceID = track.sourceID?.nonEmpty {
                return seenSourceIDs.insert(sourceID).inserted
            }
            return seenUUIDs.insert(track.id).inserted
        }
    }

    nonisolated private static func preferredDisplayName(_ values: [String], fallback: String) -> String {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return fallback }
        let grouped = Dictionary(grouping: cleaned, by: resonanceNormalizedRemoteKey)
        guard let candidates = grouped.values.max(by: { $0.count < $1.count }) else { return fallback }
        return candidates.sorted { lhs, rhs in
            let lhsAllCaps = lhs.count > 1 && lhs == lhs.uppercased() && lhs != lhs.lowercased()
            let rhsAllCaps = rhs.count > 1 && rhs == rhs.uppercased() && rhs != rhs.lowercased()
            if lhsAllCaps != rhsAllCaps { return !lhsAllCaps }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }.first ?? fallback
    }

    nonisolated fileprivate static func canonicalizeAlbumArtists(_ values: [RemoteTrackItem]) -> [RemoteTrackItem] {
        let grouped = Dictionary(grouping: values) {
            "\(resonanceNormalizedRemoteKey($0.artist))|\(resonanceNormalizedRemoteKey($0.album))"
        }
        var canonicalNames: [UUID: String] = [:]

        for albumTracks in grouped.values {
            guard !albumTracks.isEmpty else { continue }
            let artistKeys = Set(albumTracks.map { resonanceNormalizedRemoteKey($0.artist) })
            guard artistKeys.count == 1, let first = albumTracks.first else { continue }

            let albumArtistKeys = Set(albumTracks.map { resonanceNormalizedRemoteKey($0.albumArtist) })
            let albumArtistsMatchTrackArtist = albumArtistKeys.allSatisfy { artistKeys.contains($0) }
            let containsDisplayComposite = albumTracks.contains {
                $0.albumArtist.contains("•")
                    || $0.albumArtist.localizedCaseInsensitiveContains("unknown artist")
            }
            guard albumArtistsMatchTrackArtist || containsDisplayComposite else { continue }

            let canonical = preferredDisplayName(
                albumTracks.map(\.artist),
                fallback: first.artist
            )
            for track in albumTracks {
                canonicalNames[track.id] = canonical
            }
        }

        return values.map { track in
            guard let canonical = canonicalNames[track.id], track.albumArtist != canonical else { return track }
            return track.settingAlbumArtist(canonical)
        }
    }

    nonisolated private static func albumFingerprint(_ albums: [SubsonicAlbumSummary]) -> String {
        albums
            .map { "\($0.id)|\($0.songCount ?? 0)|\($0.coverArt ?? "")|\($0.year ?? 0)" }
            .sorted()
            .joined(separator: "\n")
            .data(using: .utf8)
            .map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? ""
    }

    func activateCachedCatalogAndCheckForChanges(using settings: AppSettings, forceCheck: Bool = false) async {
        guard !settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Once a cached catalog is visible, automatic scene/view appearances do
        // not need to start another task just to discover that the check is
        // intentionally deferred. Settings' explicit check still bypasses this
        // guard and is the only path that should refresh cached content.
        if !forceCheck, !tracks.isEmpty { return }

        ResonanceDiagnostics.shared.recordDeferred(
            "remote.catalogCheck.begin",
            details: [
                "backend": settings.streamBackend.shortName,
                "force": String(forceCheck),
                "trackCount": String(tracks.count)
            ]
        )

        if settings.streamBackend == .subsonic, tracks.isEmpty, let cached = pendingSubsonicCache {
            do {
                let client = try makeSubsonicClient(using: settings)
                let restored = try cached.tracks.map { try client.restoreCachedTrack($0) }
                tracks = Self.canonicalizeAlbumArtists(restored)
                serverName = cached.serverName
                lastRefresh = cached.savedAt
                connectionStatus = "Showing cached catalog — remote check available in Settings"
                catalogSyncStatus = "Cached \(tracks.count) tracks"
                ResonanceDiagnostics.shared.recordDeferred(
                    "remote.catalogCache.activated",
                    details: ["trackCount": String(tracks.count)]
                )
            } catch {
                catalogSyncStatus = "Cached catalog could not be activated: \(error.localizedDescription)"
            }
        }

        let now = Date()
        if !forceCheck, let lastAutomaticCatalogCheck, now.timeIntervalSince(lastAutomaticCatalogCheck) < 300 {
            ResonanceDiagnostics.shared.recordDeferred("remote.catalogCheck.throttled")
            return
        }
        lastAutomaticCatalogCheck = now
        lastCatalogCheck = now

        guard !isLoading else { return }
        if settings.streamBackend == .resonanceManifest {
            if tracks.isEmpty { await refresh(using: settings) }
            return
        }

        do {
            let client = try makeSubsonicClient(using: settings)
            let summaries = try await client.fetchAlbumSummaries()
            let newFingerprint = Self.albumFingerprint(summaries)
            let cachedFingerprint = pendingSubsonicCache?.albumFingerprint
            if tracks.isEmpty || cachedFingerprint != newFingerprint {
                let previousIDs = Set(tracks.compactMap(\.sourceID))
                await refresh(using: settings)
                let currentIDs = Set(tracks.compactMap(\.sourceID))
                let added = currentIDs.subtracting(previousIDs).count
                let removed = previousIDs.subtracting(currentIDs).count
                catalogSyncStatus = "Catalog updated: +\(added), −\(removed), \(tracks.count) total"
                ResonanceDiagnostics.shared.recordDeferred(
                    "remote.catalogCheck.completed",
                    details: ["result": "updated", "trackCount": String(tracks.count)]
                )
            } else {
                connectionStatus = "Connected — cached catalog is up to date"
                catalogSyncStatus = "No remote library changes found"
                ResonanceDiagnostics.shared.recordDeferred(
                    "remote.catalogCheck.completed",
                    details: ["result": "unchanged", "trackCount": String(tracks.count)]
                )
            }
        } catch is CancellationError {
            connectionStatus = tracks.isEmpty
                ? "Background catalog check cancelled"
                : "Offline — showing cached catalog"
            catalogSyncStatus = "Last check cancelled; cached catalog retained"
            ResonanceDiagnostics.shared.recordDeferred("remote.catalogCheck.cancelled")
        } catch let error as URLError where error.code == .cancelled {
            connectionStatus = tracks.isEmpty
                ? "Background catalog check cancelled"
                : "Offline — showing cached catalog"
            catalogSyncStatus = "Last check cancelled; cached catalog retained"
            ResonanceDiagnostics.shared.recordDeferred("remote.catalogCheck.cancelled", details: ["error": "URLError.cancelled"])
        } catch {
            connectionStatus = tracks.isEmpty ? "Background catalog check failed: \(error.localizedDescription)" : "Offline — showing cached catalog"
            catalogSyncStatus = "Last check failed: \(error.localizedDescription)"
            ResonanceDiagnostics.shared.recordDeferred(
                "remote.catalogCheck.failed",
                details: ["errorType": String(describing: type(of: error))]
            )
        }
    }

    func testConnection(using settings: AppSettings) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch settings.streamBackend {
            case .subsonic:
                let client = try makeSubsonicClient(using: settings)
                connectionStatus = "Testing Subsonic connection…"
                let server = try await client.ping()
                serverName = server.displayName
                connectionStatus = "Connected — \(server.displayName)"
            case .resonanceManifest:
                guard let url = configuredContentURL(path: settings.streamManifestPath, using: settings) else {
                    throw RemoteLibraryError.missingServerAddress
                }
                connectionStatus = "Testing \(url.host ?? "server")…"
                let (data, response) = try await URLSession.shared.data(for: request(for: url))
                try validate(response: response, data: data)
                let manifest = try JSONDecoder().decode(RemoteLibraryManifest.self, from: data)
                serverName = manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Remote Library"
                connectionStatus = "Connected — \(manifest.tracks.count) tracks available"
            }
        } catch {
            connectionStatus = "Connection failed: \(error.localizedDescription)"
        }
    }

    func refresh(using settings: AppSettings) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch settings.streamBackend {
            case .subsonic:
                try await refreshSubsonic(using: settings)
            case .resonanceManifest:
                try await refreshManifest(using: settings)
            }
        } catch {
            connectionStatus = "Refresh failed: \(error.localizedDescription)"
        }
    }

    func play(_ selected: RemoteTrackItem, in context: [RemoteTrackItem], using player: PlayerController) async {
        let requestGeneration = beginPlaybackPreparation()
        let ordered = context.isEmpty ? [selected] : context
        let prepared = await preparePlaybackTracks(ordered, priority: selected)
        guard requestGeneration == playbackPreparationGeneration else {
            ResonanceDiagnostics.shared.recordDeferred(
                "remote.playback.preparationDiscarded",
                details: ["operation": "track"]
            )
            return
        }
        guard let target = prepared.first(where: { $0.id == selected.id }) else { return }
        player.play(target, in: prepared)
    }

    func playAlbum(_ album: RemoteAlbum, using player: PlayerController, shuffle: Bool = false) async {
        let requestGeneration = beginPlaybackPreparation()
        let prepared = await preparePlaybackTracks(album.tracks, priority: album.tracks.first)
        guard requestGeneration == playbackPreparationGeneration else {
            ResonanceDiagnostics.shared.recordDeferred(
                "remote.playback.preparationDiscarded",
                details: ["operation": "album"]
            )
            return
        }
        guard !prepared.isEmpty else { return }
        if shuffle {
            player.shuffleAndPlay(prepared)
        } else if let first = prepared.first {
            player.play(first, in: prepared)
        }
    }

    func playArtist(_ artist: RemoteArtist, using player: PlayerController, shuffle: Bool = false) async {
        let requestGeneration = beginPlaybackPreparation()
        let ordered = artist.albums.flatMap(\.tracks)
        let prepared = await preparePlaybackTracks(ordered, priority: ordered.first)
        guard requestGeneration == playbackPreparationGeneration else {
            ResonanceDiagnostics.shared.recordDeferred(
                "remote.playback.preparationDiscarded",
                details: ["operation": "artist"]
            )
            return
        }
        guard !prepared.isEmpty else { return }
        if shuffle {
            player.shuffleAndPlay(prepared)
        } else if let first = prepared.first {
            player.play(first, in: prepared)
        }
    }

    func playNext(_ items: [RemoteTrackItem], using player: PlayerController) async {
        let requestGeneration = beginPlaybackPreparation()
        let prepared = await preparePlaybackTracks(items, priority: items.first)
        guard requestGeneration == playbackPreparationGeneration else { return }
        player.playNext(prepared)
    }

    func addToQueue(_ items: [RemoteTrackItem], using player: PlayerController) async {
        let requestGeneration = beginPlaybackPreparation()
        let prepared = await preparePlaybackTracks(items, priority: items.first)
        guard requestGeneration == playbackPreparationGeneration else { return }
        player.addToQueue(prepared)
    }

    func toggleFavorite(_ item: RemoteTrackItem, using settings: AppSettings) async {
        guard let sourceID = item.sourceID, settings.streamBackend == .subsonic else { return }
        let newValue = !item.isFavorite
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.setStarred(songID: sourceID, starred: newValue)
            updateRemoteTrack(item.id) { $0.settingStarred(newValue) }
            connectionStatus = newValue ? "Added to server favorites" : "Removed from server favorites"
        } catch {
            connectionStatus = "Could not update favorite: \(error.localizedDescription)"
        }
    }

    func markPlayed(trackID: UUID, using settings: AppSettings) async {
        guard let item = tracks.first(where: { $0.id == trackID }),
              let sourceID = item.sourceID,
              settings.streamBackend == .subsonic else { return }
        updateRemoteTrack(trackID) { $0.settingLastPlayed(Date()) }
        if let client = try? makeSubsonicClient(using: settings) {
            try? await client.scrobble(songID: sourceID)
        }
    }

    private func updateRemoteTrack(_ id: UUID, transform: (RemoteTrackItem) -> RemoteTrackItem) {
        tracks = tracks.map { $0.id == id ? transform($0) : $0 }
        playlists = playlists.map { playlist in
            RemotePlaylist(
                id: playlist.id,
                name: playlist.name,
                owner: playlist.owner,
                tracks: playlist.tracks.map { $0.id == id ? transform($0) : $0 }
            )
        }
    }

    func artworkData(for item: RemoteTrackItem) async -> Data? {
        if let encoded = item.artworkBase64, let data = Data(base64Encoded: encoded) { return data }
        guard let url = item.artworkURL else { return nil }
        if let cached = artworkCache.object(forKey: url as NSURL) { return cached as Data }

        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: url))
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  data.count <= 12 * 1_048_576 else { return nil }
            artworkCache.setObject(data as NSData, forKey: url as NSURL)
            return data
        } catch {
            return nil
        }
    }

    func refreshPlaylists(using settings: AppSettings) async {
        guard settings.streamBackend == .subsonic else {
            playlists = []
            connectionStatus = "Server playlists require the Subsonic backend"
            return
        }
        do {
            let client = try makeSubsonicClient(using: settings)
            playlists = try await client.fetchPlaylists()
            connectionStatus = "Loaded \(playlists.count) server playlists"
        } catch {
            connectionStatus = "Playlist refresh failed: \(error.localizedDescription)"
        }
    }

    func createPlaylist(named rawName: String, using settings: AppSettings) async -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.createPlaylist(name: name)
            playlists = try await client.fetchPlaylists()
            connectionStatus = "Created playlist “\(name)”"
            return true
        } catch {
            connectionStatus = "Could not create playlist: \(error.localizedDescription)"
            return false
        }
    }

    func renamePlaylist(_ playlist: RemotePlaylist, to rawName: String, using settings: AppSettings) async -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.updatePlaylist(id: playlist.id, name: name)
            playlists = try await client.fetchPlaylists()
            connectionStatus = "Renamed playlist to “\(name)”"
            return true
        } catch {
            connectionStatus = "Could not rename playlist: \(error.localizedDescription)"
            return false
        }
    }

    func deletePlaylist(_ playlist: RemotePlaylist, using settings: AppSettings) async -> Bool {
        guard settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.deletePlaylist(id: playlist.id)
            playlists.removeAll { $0.id == playlist.id }
            connectionStatus = "Deleted playlist “\(playlist.name)”"
            return true
        } catch {
            connectionStatus = "Could not delete playlist: \(error.localizedDescription)"
            return false
        }
    }

    func add(_ items: [RemoteTrackItem], to playlist: RemotePlaylist, using settings: AppSettings) async -> Bool {
        let existing = Set(playlist.tracks.compactMap(\.sourceID))
        let songIDs = items.compactMap(\.sourceID).filter { !existing.contains($0) }
        guard !songIDs.isEmpty, settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.updatePlaylist(id: playlist.id, songIDsToAdd: songIDs)
            if let refreshed = try? await client.fetchPlaylist(id: playlist.id),
               let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[index] = refreshed
            }
            connectionStatus = "Added \(songIDs.count) track\(songIDs.count == 1 ? "" : "s") to “\(playlist.name)”"
            return true
        } catch {
            connectionStatus = "Could not add tracks: \(error.localizedDescription)"
            return false
        }
    }

    func removeTrack(at index: Int, from playlist: RemotePlaylist, using settings: AppSettings) async -> Bool {
        guard playlist.tracks.indices.contains(index), settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            try await client.updatePlaylist(id: playlist.id, songIndexesToRemove: [index])
            if let refreshed = try? await client.fetchPlaylist(id: playlist.id),
               let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[playlistIndex] = refreshed
            }
            return true
        } catch {
            connectionStatus = "Could not remove track: \(error.localizedDescription)"
            return false
        }
    }

    func replacePlaylistOrder(
        _ playlist: RemotePlaylist,
        with orderedTracks: [RemoteTrackItem],
        using settings: AppSettings
    ) async -> Bool {
        let songIDs = orderedTracks.compactMap(\.sourceID)
        guard songIDs.count == orderedTracks.count, settings.streamBackend == .subsonic else { return false }
        do {
            let client = try makeSubsonicClient(using: settings)
            let indexes = Array(playlist.tracks.indices).sorted(by: >)
            try await client.updatePlaylist(
                id: playlist.id,
                songIDsToAdd: songIDs,
                songIndexesToRemove: indexes
            )
            if let refreshed = try? await client.fetchPlaylist(id: playlist.id),
               let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[playlistIndex] = refreshed
            }
            connectionStatus = "Updated playlist order"
            return true
        } catch {
            connectionStatus = "Could not reorder playlist: \(error.localizedDescription)"
            return false
        }
    }

    func playPlaylist(_ playlist: RemotePlaylist, using player: PlayerController, shuffle: Bool = false) async {
        let requestGeneration = beginPlaybackPreparation()
        let prepared = await preparePlaybackTracks(playlist.tracks, priority: playlist.tracks.first)
        guard requestGeneration == playbackPreparationGeneration else {
            ResonanceDiagnostics.shared.recordDeferred(
                "remote.playback.preparationDiscarded",
                details: ["operation": "playlist"]
            )
            return
        }
        guard !prepared.isEmpty else { return }
        if shuffle {
            player.shuffleAndPlay(prepared)
        } else if let first = prepared.first {
            player.play(first, in: prepared)
        }
    }

    private func refreshManifest(using settings: AppSettings) async throws {
        guard let manifestURL = configuredContentURL(path: settings.streamManifestPath, using: settings) else {
            throw RemoteLibraryError.missingServerAddress
        }
        connectionStatus = "Loading Resonance manifest…"
        let (data, response) = try await URLSession.shared.data(for: request(for: manifestURL))
        try validate(response: response, data: data)
        let manifest = try JSONDecoder().decode(RemoteLibraryManifest.self, from: data)
        let resolved = manifest.tracks.compactMap { resolveManifestTrack($0, relativeTo: manifestURL) }
        let unique = Self.canonicalizeAlbumArtists(Self.uniqueTracks(resolved))
        tracks = unique
        playlists = []
        serverName = manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Remote Library"
        lastRefresh = Date()
        connectionStatus = "Connected — \(unique.count) tracks indexed"
        if let stored = try? JSONEncoder().encode(unique) {
            try? stored.write(to: Self.cachedTracksURL, options: .atomic)
        }
    }

    private func refreshSubsonic(using settings: AppSettings) async throws {
        let client = try makeSubsonicClient(using: settings)
        connectionStatus = "Connecting to Navidrome / Subsonic…"
        let server = try await client.ping()
        serverName = server.displayName

        connectionStatus = "Loading album index…"
        let summaries = try await client.fetchAlbumSummaries()
        var resolved: [RemoteTrackItem] = []
        resolved.reserveCapacity(summaries.reduce(0) { $0 + max(0, $1.songCount ?? 0) })

        let batchSize = 8
        for batchStart in stride(from: 0, to: summaries.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, summaries.count)
            let batch = Array(summaries[batchStart..<batchEnd])
            let batchTracks = await withTaskGroup(of: [RemoteTrackItem].self, returning: [RemoteTrackItem].self) { group in
                for summary in batch {
                    group.addTask {
                        (try? await client.fetchTracks(for: summary)) ?? []
                    }
                }
                var result: [RemoteTrackItem] = []
                for await albumTracks in group { result.append(contentsOf: albumTracks) }
                return result
            }
            resolved.append(contentsOf: batchTracks)
            if batchEnd == summaries.count || batchEnd % (batchSize * 8) == 0 {
                connectionStatus = "Indexing albums \(batchEnd) of \(summaries.count)…"
            }
        }

        let deduplicated = Self.canonicalizeAlbumArtists(Self.uniqueTracks(resolved))
        tracks = deduplicated.sorted {
            ($0.artist, $0.album, $0.discNumber, $0.trackNumber, $0.title) <
            ($1.artist, $1.album, $1.discNumber, $1.trackNumber, $1.title)
        }
        connectionStatus = "Loading server playlists…"
        playlists = (try? await client.fetchPlaylists()) ?? []
        let refreshedAt = Date()
        lastRefresh = refreshedAt
        connectionStatus = "Connected — \(tracks.count) unique tracks and \(playlists.count) playlists from \(server.displayName)"
        let catalog = CachedRemoteCatalog(
            serverName: server.displayName,
            savedAt: refreshedAt,
            albumFingerprint: Self.albumFingerprint(summaries),
            tracks: tracks.compactMap(CachedRemoteTrack.init)
        )
        pendingSubsonicCache = catalog
        if let encoded = try? JSONEncoder().encode(catalog) {
            try? encoded.write(to: Self.cachedSubsonicCatalogURL, options: .atomic)
        }
        catalogSyncStatus = "Cached \(catalog.tracks.count) tracks for fast relaunch"
        // Authenticated Subsonic stream URLs are never written to disk.
        try? FileManager.default.removeItem(at: Self.cachedTracksURL)
    }

    private func makeSubsonicClient(using settings: AppSettings) throws -> SubsonicClient {
        guard !settings.streamUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RemoteLibraryError.missingUsername
        }
        guard !settings.streamPassword.isEmpty else { throw RemoteLibraryError.missingPassword }
        guard let apiURL = configuredContentURL(path: settings.streamManifestPath, using: settings) else {
            throw RemoteLibraryError.missingServerAddress
        }
        return SubsonicClient(
            apiBaseURL: apiURL,
            username: settings.streamUsername.trimmingCharacters(in: .whitespacesAndNewlines),
            password: settings.streamPassword
        )
    }

    private func configuredContentURL(path: String, using settings: AppSettings) -> URL? {
        let rawHost = settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawHost.isEmpty else { return nil }

        var components: URLComponents
        if rawHost.contains("://"), let supplied = URLComponents(string: rawHost) {
            components = supplied
        } else {
            components = URLComponents()
            components.scheme = settings.streamUseHTTPS ? "https" : "http"
            components.host = rawHost
        }

        let trimmedPort = settings.streamPort.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPort.isEmpty, let port = Int(trimmedPort), port > 0 { components.port = port }
        components.query = nil
        components.fragment = nil

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if requestedPath.isEmpty {
            components.path = basePath.isEmpty ? "/" : "/" + basePath
        } else if basePath == requestedPath || basePath.hasSuffix("/" + requestedPath) {
            components.path = "/" + basePath
        } else {
            components.path = "/" + [basePath, requestedPath].filter { !$0.isEmpty }.joined(separator: "/")
        }
        return components.url
    }

    private func preparePlaybackTracks(
        _ items: [RemoteTrackItem],
        priority: RemoteTrackItem?
    ) async -> [Track] {
        var artworkByKey: [String: Data] = [:]
        // Only the selected track's artwork is needed to start playback. The
        // previous implementation fetched up to 24 album covers serially
        // before handing the queue to PlayerController. On a large remote
        // queue, repeated taps could leave several preparation tasks alive
        // and return a burst of stale player rebuilds after navigation.
        if let item = priority, let data = await artworkData(for: item) {
            artworkByKey[item.albumKey] = data
        }

        if Task.isCancelled { return [] }
        return items.map { item in item.asTrack(artworkData: artworkByKey[item.albumKey]) }
    }

    private func beginPlaybackPreparation() -> Int {
        playbackPreparationGeneration &+= 1
        return playbackPreparationGeneration
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("application/json, audio/*, image/*;q=0.9, */*;q=0.1", forHTTPHeaderField: "Accept")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw RemoteLibraryError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteLibraryError.httpStatus(http.statusCode, String(data: data.prefix(300), encoding: .utf8))
        }
    }

    private func resolveManifestTrack(_ record: RemoteTrackRecord, relativeTo manifestURL: URL) -> RemoteTrackItem? {
        guard let streamURL = URL(string: record.path, relativeTo: manifestURL)?.absoluteURL else { return nil }
        let artworkURL = record.artwork.flatMap { URL(string: $0, relativeTo: manifestURL)?.absoluteURL }
        let stableSource = record.id?.nonEmpty ?? streamURL.absoluteString
        return RemoteTrackItem(
            id: UUID(uuidString: stableSource) ?? Self.stableUUID(for: stableSource),
            sourceID: record.id?.nonEmpty ?? record.path,
            title: record.title.nonEmpty ?? streamURL.deletingPathExtension().lastPathComponent,
            artist: record.artist.nonEmpty ?? "Unknown Artist",
            albumArtist: record.albumArtist?.nonEmpty ?? record.artist.nonEmpty ?? "Unknown Artist",
            album: record.album.nonEmpty ?? "Unknown Album",
            trackNumber: max(0, record.trackNumber ?? 0),
            discNumber: max(1, record.discNumber ?? 1),
            releaseYear: max(0, record.releaseYear ?? 0),
            duration: max(0, record.duration ?? 0),
            fileSizeBytes: max(0, record.fileSize ?? 0),
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: record.artworkBase64,
            coverArtID: nil,
            starred: nil,
            dateAdded: nil,
            lastPlayed: nil
        )
    }

    nonisolated fileprivate static func stableUUID(for string: String) -> UUID {
        func hash(seed: UInt64) -> UInt64 {
            var value = seed
            for byte in string.utf8 {
                value ^= UInt64(byte)
                value &*= 1_099_511_628_211
            }
            return value
        }
        let high = hash(seed: 14_695_981_039_346_656_037)
        let low = hash(seed: 7_801_984_618_907_684_001)
        let raw = String(format: "%016llX%016llX", high, low)
        let uuidString = "\(raw.prefix(8))-\(raw.dropFirst(8).prefix(4))-\(raw.dropFirst(12).prefix(4))-\(raw.dropFirst(16).prefix(4))-\(raw.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

private struct SubsonicClient: Sendable {
    let apiBaseURL: URL
    let username: String
    let password: String

    func ping() async throws -> SubsonicServerInfo {
        let envelope: SubsonicPingEnvelope = try await fetch("ping.view", queryItems: [])
        try validate(status: envelope.response.status, error: envelope.response.error)
        return SubsonicServerInfo(
            type: envelope.response.type,
            version: envelope.response.serverVersion,
            openSubsonic: envelope.response.openSubsonic ?? false
        )
    }

    func fetchAlbumSummaries() async throws -> [SubsonicAlbumSummary] {
        let pageSize = 500
        var offset = 0
        var albums: [SubsonicAlbumSummary] = []

        while true {
            let envelope: SubsonicAlbumListEnvelope = try await fetch(
                "getAlbumList2.view",
                queryItems: [
                    URLQueryItem(name: "type", value: "alphabeticalByName"),
                    URLQueryItem(name: "size", value: String(pageSize)),
                    URLQueryItem(name: "offset", value: String(offset))
                ]
            )
            try validate(status: envelope.response.status, error: envelope.response.error)
            let page = envelope.response.albumList2?.album ?? []
            albums.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += page.count
            if offset >= 100_000 { break }
        }
        return albums
    }

    func fetchTracks(for summary: SubsonicAlbumSummary) async throws -> [RemoteTrackItem] {
        let envelope: SubsonicAlbumEnvelope = try await fetch(
            "getAlbum.view",
            queryItems: [URLQueryItem(name: "id", value: summary.id)]
        )
        try validate(status: envelope.response.status, error: envelope.response.error)
        guard let album = envelope.response.album else { return [] }

        return try (album.song ?? []).map { song in
            try makeRemoteTrack(
                from: song,
                fallbackAlbum: album.name,
                fallbackArtist: album.artist ?? summary.artist,
                fallbackCoverArt: album.coverArt ?? summary.coverArt,
                fallbackYear: album.year ?? summary.year
            )
        }
    }

    func fetchPlaylists() async throws -> [RemotePlaylist] {
        let envelope: SubsonicPlaylistsEnvelope = try await fetch("getPlaylists.view", queryItems: [])
        try validate(status: envelope.response.status, error: envelope.response.error)
        let summaries = envelope.response.playlists?.playlist ?? []
        return await withTaskGroup(of: RemotePlaylist?.self, returning: [RemotePlaylist].self) { group in
            for summary in summaries {
                group.addTask { try? await self.fetchPlaylist(id: summary.id) }
            }
            var result: [RemotePlaylist] = []
            for await playlist in group {
                if let playlist { result.append(playlist) }
            }
            return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    func fetchPlaylist(id: String) async throws -> RemotePlaylist {
        let envelope: SubsonicPlaylistEnvelope = try await fetch(
            "getPlaylist.view",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
        try validate(status: envelope.response.status, error: envelope.response.error)
        guard let playlist = envelope.response.playlist else {
            throw RemoteLibraryError.invalidResponse
        }
        let tracks = try (playlist.entry ?? []).map {
            try makeRemoteTrack(
                from: $0,
                fallbackAlbum: $0.album,
                fallbackArtist: $0.albumArtist ?? $0.artist,
                fallbackCoverArt: playlist.coverArt,
                fallbackYear: $0.year
            )
        }
        return RemotePlaylist(
            id: playlist.id,
            name: playlist.name,
            owner: playlist.owner,
            tracks: RemoteLibraryStore.uniqueTracks(tracks)
        )
    }

    func createPlaylist(name: String, songIDs: [String] = []) async throws {
        var items = [URLQueryItem(name: "name", value: name)]
        items.append(contentsOf: songIDs.map { URLQueryItem(name: "songId", value: $0) })
        let envelope: SubsonicStatusEnvelope = try await fetch("createPlaylist.view", queryItems: items)
        try validate(status: envelope.response.status, error: envelope.response.error)
    }

    func updatePlaylist(
        id: String,
        name: String? = nil,
        songIDsToAdd: [String] = [],
        songIndexesToRemove: [Int] = []
    ) async throws {
        var items = [URLQueryItem(name: "playlistId", value: id)]
        if let name { items.append(URLQueryItem(name: "name", value: name)) }
        items.append(contentsOf: songIDsToAdd.map { URLQueryItem(name: "songIdToAdd", value: $0) })
        items.append(contentsOf: songIndexesToRemove.map { URLQueryItem(name: "songIndexToRemove", value: String($0)) })
        let envelope: SubsonicStatusEnvelope = try await fetch("updatePlaylist.view", queryItems: items)
        try validate(status: envelope.response.status, error: envelope.response.error)
    }

    func deletePlaylist(id: String) async throws {
        let envelope: SubsonicStatusEnvelope = try await fetch(
            "deletePlaylist.view",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
        try validate(status: envelope.response.status, error: envelope.response.error)
    }

    private func makeRemoteTrack(
        from song: SubsonicSong,
        fallbackAlbum: String?,
        fallbackArtist: String?,
        fallbackCoverArt: String?,
        fallbackYear: Int?
    ) throws -> RemoteTrackItem {
        let streamURL = try endpointURL(
            "stream.view",
            queryItems: [
                URLQueryItem(name: "id", value: song.id),
                URLQueryItem(name: "format", value: "raw"),
                URLQueryItem(name: "estimateContentLength", value: "true")
            ]
        )
        let coverIdentifier = song.coverArt?.nonEmpty ?? fallbackCoverArt?.nonEmpty
        let artworkURL = try coverIdentifier.map {
            try endpointURL(
                "getCoverArt.view",
                queryItems: [
                    URLQueryItem(name: "id", value: $0),
                    URLQueryItem(name: "size", value: "1200")
                ]
            )
        }
        let artist = song.artist?.nonEmpty
            ?? fallbackArtist?.nonEmpty
            ?? song.albumArtist?.nonEmpty
            ?? song.displayAlbumArtist?.nonEmpty
            ?? "Unknown Artist"
        let albumArtist = song.albumArtist?.nonEmpty
            ?? artist
        let albumTitle = song.album?.nonEmpty ?? fallbackAlbum?.nonEmpty ?? "Unknown Album"
        let stableSource = "subsonic|\(apiBaseURL.absoluteString)|\(song.id)"

        return RemoteTrackItem(
            id: RemoteLibraryStore.stableUUID(for: stableSource),
            sourceID: song.id,
            title: song.title.nonEmpty ?? "Unknown Track",
            artist: artist,
            albumArtist: albumArtist,
            album: albumTitle,
            trackNumber: max(0, song.track ?? 0),
            discNumber: max(1, song.discNumber ?? 1),
            releaseYear: max(0, song.year ?? fallbackYear ?? 0),
            duration: max(0, song.duration ?? 0),
            fileSizeBytes: max(0, song.size ?? 0),
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: nil,
            coverArtID: coverIdentifier,
            starred: song.starred != nil,
            dateAdded: parseSubsonicDate(song.created),
            lastPlayed: parseSubsonicDate(song.played)
        )
    }

    func restoreCachedTrack(_ cached: CachedRemoteTrack) throws -> RemoteTrackItem {
        let streamURL = try endpointURL(
            "stream.view",
            queryItems: [
                URLQueryItem(name: "id", value: cached.sourceID),
                URLQueryItem(name: "format", value: "raw"),
                URLQueryItem(name: "estimateContentLength", value: "true")
            ]
        )
        let artworkURL = try cached.coverArtID.map { coverID in
            try endpointURL(
                "getCoverArt.view",
                queryItems: [
                    URLQueryItem(name: "id", value: coverID),
                    URLQueryItem(name: "size", value: "1200")
                ]
            )
        }
        return RemoteTrackItem(
            id: cached.id,
            sourceID: cached.sourceID,
            title: cached.title,
            artist: cached.artist,
            albumArtist: cached.albumArtist.nonEmpty ?? cached.artist,
            album: cached.album,
            trackNumber: cached.trackNumber,
            discNumber: cached.discNumber,
            releaseYear: cached.releaseYear,
            duration: cached.duration,
            fileSizeBytes: cached.fileSizeBytes,
            streamURL: streamURL,
            artworkURL: artworkURL,
            artworkBase64: nil,
            coverArtID: cached.coverArtID,
            starred: cached.starred,
            dateAdded: cached.dateAdded,
            lastPlayed: cached.lastPlayed
        )
    }

    func setStarred(songID: String, starred: Bool) async throws {
        let endpoint = starred ? "star.view" : "unstar.view"
        let envelope: SubsonicStatusEnvelope = try await fetch(
            endpoint,
            queryItems: [URLQueryItem(name: "id", value: songID)]
        )
        try validate(status: envelope.response.status, error: envelope.response.error)
    }

    func scrobble(songID: String) async throws {
        let envelope: SubsonicStatusEnvelope = try await fetch(
            "scrobble.view",
            queryItems: [
                URLQueryItem(name: "id", value: songID),
                URLQueryItem(name: "submission", value: "true")
            ]
        )
        try validate(status: envelope.response.status, error: envelope.response.error)
    }

    private func fetch<T: Decodable & Sendable>(_ endpoint: String, queryItems: [URLQueryItem]) async throws -> T {
        let url = try endpointURL(endpoint, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteLibraryError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteLibraryError.httpStatus(http.statusCode, String(data: data.prefix(300), encoding: .utf8))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let preview = String(data: data.prefix(300), encoding: .utf8)
            throw RemoteLibraryError.subsonicDecoding(preview)
        }
    }

    private func endpointURL(_ endpoint: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw RemoteLibraryError.invalidServerAddress
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/" + endpoint

        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
        let tokenSource = Data((password + salt).utf8)
        let token = Insecure.MD5.hash(data: tokenSource).map { String(format: "%02x", $0) }.joined()
        components.queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "Resonance"),
            URLQueryItem(name: "f", value: "json")
        ] + queryItems
        guard let url = components.url else { throw RemoteLibraryError.invalidServerAddress }
        return url
    }

    private func validate(status: String, error: SubsonicErrorInfo?) throws {
        guard status.lowercased() == "ok" else {
            throw RemoteLibraryError.subsonicError(error?.code, error?.message)
        }
    }
}

private struct SubsonicServerInfo: Sendable {
    let type: String?
    let version: String?
    let openSubsonic: Bool

    var displayName: String {
        let server = type?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Subsonic server"
        if let version = version?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return "\(server) \(version)"
        }
        return openSubsonic ? "\(server) (OpenSubsonic)" : server
    }
}

private struct SubsonicErrorInfo: Decodable, Sendable {
    let code: Int?
    let message: String?
}

private struct SubsonicPingEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let type: String?
        let serverVersion: String?
        let openSubsonic: Bool?
        let error: SubsonicErrorInfo?
    }
}

private struct SubsonicAlbumListEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let albumList2: AlbumList?
        let error: SubsonicErrorInfo?
    }

    struct AlbumList: Decodable, Sendable {
        let album: [SubsonicAlbumSummary]?
    }
}

private struct SubsonicAlbumSummary: Decodable, Sendable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
    let songCount: Int?
    let year: Int?
}

private struct SubsonicAlbumEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let album: Album?
        let error: SubsonicErrorInfo?
    }

    struct Album: Decodable, Sendable {
        let id: String
        let name: String
        let artist: String?
        let coverArt: String?
        let year: Int?
        let song: [SubsonicSong]?
    }
}

private struct SubsonicSong: Decodable, Sendable {
    let id: String
    let title: String
    let album: String?
    let artist: String?
    let albumArtist: String?
    let displayAlbumArtist: String?
    let track: Int?
    let discNumber: Int?
    let year: Int?
    let duration: Double?
    let size: Int64?
    let coverArt: String?
    let starred: String?
    let created: String?
    let played: String?
}


private struct SubsonicStatusEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let error: SubsonicErrorInfo?
    }
}

private struct SubsonicPlaylistsEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let playlists: PlaylistContainer?
        let error: SubsonicErrorInfo?
    }

    struct PlaylistContainer: Decodable, Sendable {
        let playlist: [Summary]?
    }

    struct Summary: Decodable, Sendable {
        let id: String
        let name: String
        let owner: String?
        let songCount: Int?
        let duration: Double?
        let coverArt: String?
    }
}

private struct SubsonicPlaylistEnvelope: Decodable, Sendable {
    let response: Response
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }

    struct Response: Decodable, Sendable {
        let status: String
        let playlist: PlaylistPayload?
        let error: SubsonicErrorInfo?
    }

    struct PlaylistPayload: Decodable, Sendable {
        let id: String
        let name: String
        let owner: String?
        let coverArt: String?
        let entry: [SubsonicSong]?
    }
}

enum RemoteLibraryError: LocalizedError {
    case invalidResponse
    case invalidServerAddress
    case missingServerAddress
    case missingUsername
    case missingPassword
    case httpStatus(Int, String?)
    case subsonicError(Int?, String?)
    case subsonicDecoding(String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .invalidServerAddress:
            return "The server address or API path is invalid."
        case .missingServerAddress:
            return "Enter a server URL or Tailscale host first."
        case .missingUsername:
            return "Enter the Navidrome / Subsonic username."
        case .missingPassword:
            return "Enter the Navidrome / Subsonic password."
        case let .httpStatus(code, message):
            if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                return "Server returned HTTP \(code): \(message)"
            }
            return "Server returned HTTP \(code)."
        case let .subsonicError(code, message):
            let codeText = code.map { " (code \($0))" } ?? ""
            return (message?.nonEmpty ?? "The Subsonic server rejected the request") + codeText
        case let .subsonicDecoding(preview):
            if let preview = preview?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                return "The server did not return Subsonic JSON: \(preview)"
            }
            return "The server did not return valid Subsonic JSON."
        }
    }
}


private func parseSubsonicDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

nonisolated func resonanceNormalizedRemoteKey(_ value: String) -> String {
    let cleanedScalars = value.unicodeScalars.filter { scalar in
        !CharacterSet.controlCharacters.contains(scalar) && !CharacterSet.illegalCharacters.contains(scalar)
    }
    let folded = String(String.UnicodeScalarView(cleanedScalars)).folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
    return String(
        folded
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : " "
            }
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    ).lowercased()
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

struct RemoteDownloadProgress: Identifiable, Sendable {
    let id: UUID
    let title: String
    let completed: Int
    let total: Int
    let state: State

    enum State: String, Sendable {
        case queued
        case downloading
        case completed
        case skipped
        case failed
        case cancelled
    }

    var fraction: Double {
        guard total > 0 else { return state == .completed || state == .skipped ? 1 : 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

enum RemoteDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The remote track has no downloadable stream URL."
        case .invalidResponse: "The remote server returned an invalid download response."
        case let .httpStatus(code): "The remote server returned HTTP \(code)."
        case .emptyResponse: "The remote server returned an empty audio file."
        case .fileWriteFailed: "The downloaded audio file could not be saved to the local library."
        }
    }
}

@MainActor
final class RemoteDownloadManager: ObservableObject {
    private static let persistedQueueIDsKey = "resonance.remoteDownloadQueueIDs"

    @Published private(set) var isDownloading = false
    @Published private(set) var currentTitle = ""
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var currentCompletedBytes: Int64 = 0
    @Published private(set) var currentTotalBytes: Int64 = 0
    @Published private(set) var lastMessage = ""
    @Published private(set) var itemProgress: [UUID: RemoteDownloadProgress] = [:]
    @Published private(set) var downloadQueue: [RemoteDownloadProgress] = []
    @Published private(set) var pendingReplacementCount = 0
    @Published private(set) var pendingReplacementDescription = ""

    var hasPersistedQueue: Bool {
        !persistedQueueIDs().isEmpty
    }

    private struct DownloadResult: Sendable {
        let bytes: Int64
        let skipped: Bool
        let destination: URL
    }

    private var downloadTask: Task<Void, Never>?
    private var activeWorker: Task<DownloadResult, Error>?
    private var activeTrackID: UUID?
    private var individuallyCancelledTrackIDs: Set<UUID> = []
    private var requeueRequests: [UUID: RemoteTrackItem] = [:]
    private var activeTracksByID: [UUID: RemoteTrackItem] = [:]
    private var pendingTracks: [RemoteTrackItem] = []
    private weak var pendingLibrary: LibraryStore?

    func requestDownload(_ remoteTracks: [RemoteTrackItem], into library: LibraryStore) {
        let tracks = remoteTracks.reduce(into: [RemoteTrackItem]()) { result, track in
            if !result.contains(where: { $0.id == track.id }) { result.append(track) }
        }
        guard !tracks.isEmpty, !isDownloading else {
            if isDownloading { lastMessage = "A download is already in progress" }
            return
        }

        ResonanceDiagnostics.shared.recordDeferred(
            "download.request",
            details: ["trackCount": String(tracks.count), "active": String(isDownloading)]
        )

        let duplicates = tracks.filter {
            FileManager.default.fileExists(atPath: Self.destinationURL(for: $0, in: library.sharedMusicFolderURL).path)
        }
        if !duplicates.isEmpty {
            pendingTracks = tracks
            pendingLibrary = library
            pendingReplacementCount = duplicates.count
            pendingReplacementDescription = duplicates.count == 1
                ? "A local file with the same name already exists. Replace it?"
                : "\(duplicates.count) local files with the same names already exist. Replace them?"
            return
        }

        startDownload(tracks, into: library, replacingExisting: false)
    }

    func confirmReplacement() {
        guard !pendingTracks.isEmpty, let library = pendingLibrary else {
            cancelPendingReplacement()
            return
        }
        let tracks = pendingTracks
        cancelPendingReplacement()
        startDownload(tracks, into: library, replacingExisting: true)
    }

    func cancelPendingReplacement() {
        pendingTracks = []
        pendingLibrary = nil
        pendingReplacementCount = 0
        pendingReplacementDescription = ""
    }

    func cancel() {
        guard isDownloading else { return }
        activeWorker?.cancel()
        downloadTask?.cancel()
        clearPersistedQueue()
        ResonanceDiagnostics.shared.recordDeferred("download.cancelAll")
        lastMessage = "Cancelling download…"
    }

    func cancelDownload(_ id: UUID) {
        guard isDownloading, let current = itemProgress[id] else { return }
        guard current.state == .queued || current.state == .downloading else { return }
        individuallyCancelledTrackIDs.insert(id)
        removePersistedTrack(id)
        if activeTrackID == id {
            activeWorker?.cancel()
        } else {
            setProgress(
                RemoteDownloadProgress(
                    id: current.id,
                    title: current.title,
                    completed: current.completed,
                    total: current.total,
                    state: .cancelled
                )
            )
            completedCount += 1
        }
    }

    func requeueDownload(_ id: UUID) {
        guard isDownloading, let current = itemProgress[id], current.state == .cancelled,
              let track = activeTracksByID[id] else { return }
        individuallyCancelledTrackIDs.remove(id)
        requeueRequests[id] = track
        addPersistedTrack(id)
        setProgress(
            RemoteDownloadProgress(
                id: current.id,
                title: current.title,
                completed: 0,
                total: 0,
                state: .queued
            )
        )
        completedCount = max(0, completedCount - 1)
    }

    func resumePersistedDownloads(from remoteTracks: [RemoteTrackItem], into library: LibraryStore) {
        guard !isDownloading else { return }
        let savedIDs = persistedQueueIDs()
        guard !savedIDs.isEmpty else { return }
        guard !remoteTracks.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: remoteTracks.map { ($0.id, $0) })
        let matchedTracks = savedIDs.compactMap { byID[$0] }
        guard !matchedTracks.isEmpty else { return }
        let candidates = matchedTracks.filter {
            !FileManager.default.fileExists(atPath: Self.destinationURL(for: $0, in: library.sharedMusicFolderURL).path)
        }
        guard !candidates.isEmpty else {
            clearPersistedQueue()
            return
        }
        ResonanceDiagnostics.shared.recordDeferred(
            "download.resume",
            details: ["trackCount": String(candidates.count)]
        )
        startDownload(candidates, into: library, replacingExisting: false)
    }

    private func startDownload(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) {
        downloadTask?.cancel()
        persistQueue(tracks.map(\.id))
        downloadTask = Task { [weak self] in
            await self?.performDownload(
                tracks,
                into: library,
                replacingExisting: replacingExisting
            )
        }
    }

    private func performDownload(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) async {
        isDownloading = true
        completedCount = 0
        totalCount = tracks.count
        currentCompletedBytes = 0
        currentTotalBytes = 0
        individuallyCancelledTrackIDs = []
        requeueRequests = [:]
        activeTracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.begin",
            details: ["trackCount": String(tracks.count), "replacingExisting": String(replacingExisting)]
        )
        lastMessage = "Preparing \(tracks.count) download\(tracks.count == 1 ? "" : "s")…"
        let initialQueue = tracks.map {
            RemoteDownloadProgress(id: $0.id, title: $0.title, completed: 0, total: 0, state: .queued)
        }
        itemProgress = Dictionary(uniqueKeysWithValues: initialQueue.map { ($0.id, $0) })
        downloadQueue = initialQueue
        defer {
            isDownloading = false
            currentTitle = ""
            currentCompletedBytes = 0
            currentTotalBytes = 0
            activeWorker = nil
            activeTrackID = nil
            requeueRequests = [:]
            activeTracksByID = [:]
            downloadTask = nil
        }

        var pendingTracks = tracks
        while !pendingTracks.isEmpty || !requeueRequests.isEmpty {
            for (_, track) in requeueRequests where !pendingTracks.contains(where: { $0.id == track.id }) {
                pendingTracks.append(track)
            }
            requeueRequests.removeAll()
            guard !pendingTracks.isEmpty else { continue }
            let track = pendingTracks.removeFirst()
            if individuallyCancelledTrackIDs.contains(track.id) {
                if itemProgress[track.id]?.state != .cancelled {
                    setProgress(
                        RemoteDownloadProgress(
                            id: track.id,
                            title: track.title,
                            completed: 0,
                            total: 0,
                            state: .cancelled
                        )
                    )
                    completedCount += 1
                }
                continue
            }
            if Task.isCancelled {
                break
            }
            currentTitle = track.title
            currentCompletedBytes = 0
            currentTotalBytes = max(0, track.fileSizeBytes)
            activeTrackID = track.id
            do {
                let progressStream = AsyncStream<DownloadByteProgress>.makeStream(
                    bufferingPolicy: .bufferingNewest(1)
                )
                let destinationRoot = library.sharedMusicFolderURL
                let worker = Task.detached(priority: .utility) {
                    defer { progressStream.continuation.finish() }
                    return try await Self.downloadOne(
                        track,
                        into: destinationRoot,
                        replacingExisting: replacingExisting
                    ) { completed, total in
                        progressStream.continuation.yield(DownloadByteProgress(completed: completed, total: total))
                    }
                }
                activeWorker = worker
                await withTaskCancellationHandler(operation: {
                    var lastProgressPublication = Date.distantPast
                    for await progress in progressStream.stream {
                        let now = Date()
                        let isFinal = progress.total > 0 && progress.completed >= progress.total
                        // Keep byte-level progress smooth in the queue without invalidating the
                        // entire streaming catalog on every network callback.
                        guard isFinal || now.timeIntervalSince(lastProgressPublication) >= 0.40 else { continue }
                        lastProgressPublication = now
                        currentCompletedBytes = progress.completed
                        currentTotalBytes = progress.total
                        setProgress(
                            RemoteDownloadProgress(
                                id: track.id,
                                title: track.title,
                                completed: Int(min(Int64(Int.max), progress.completed)),
                                total: Int(min(Int64(Int.max), progress.total)),
                                state: .downloading
                            )
                        )
                    }
                }, onCancel: {
                    worker.cancel()
                })
                let result = try await worker.value
                activeWorker = nil
                activeTrackID = nil
                completedCount += 1
                removeProgress(track.id)
                await library.refreshDownloadedTrack(at: result.destination)
                removePersistedTrack(track.id)
                ResonanceDiagnostics.shared.recordDeferred(
                    "download.track.completed",
                    details: ["completedCount": String(completedCount), "totalCount": String(totalCount)]
                )
            } catch is CancellationError {
                activeWorker = nil
                activeTrackID = nil
                setProgress(
                    RemoteDownloadProgress(
                        id: track.id,
                        title: track.title,
                        completed: Int(min(Int64(Int.max), currentCompletedBytes)),
                        total: Int(min(Int64(Int.max), currentTotalBytes)),
                        state: .cancelled
                    )
                )
                completedCount += 1
                removePersistedTrack(track.id)
                if Task.isCancelled { break }
                continue
            } catch {
                activeWorker = nil
                activeTrackID = nil
                completedCount += 1
                setProgress(
                    RemoteDownloadProgress(
                        id: track.id,
                        title: track.title,
                        completed: 0,
                        total: 0,
                        state: .failed
                    )
                )
                lastMessage = "Download failed: \(error.localizedDescription)"
            }
        }

        let succeeded = completedCount - itemProgress.values.filter { $0.state == .failed || $0.state == .cancelled }.count
        if Task.isCancelled || itemProgress.values.contains(where: { $0.state == .cancelled }) {
            lastMessage = "Download cancelled after \(succeeded) track\(succeeded == 1 ? "" : "s")"
        } else {
            lastMessage = succeeded == tracks.count
            ? "Downloaded \(succeeded) track\(succeeded == 1 ? "" : "s") to the local library"
            : "Downloaded \(succeeded) of \(tracks.count) tracks; review failed items"
        }
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.end",
            details: ["succeeded": String(succeeded), "totalCount": String(tracks.count), "cancelled": String(Task.isCancelled)]
        )
    }

    private func persistedQueueIDs() -> [UUID] {
        (UserDefaults.standard.array(forKey: Self.persistedQueueIDsKey) as? [String] ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    private func persistQueue(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: Self.persistedQueueIDsKey)
    }

    private func addPersistedTrack(_ id: UUID) {
        var ids = persistedQueueIDs()
        if !ids.contains(id) { ids.append(id) }
        persistQueue(ids)
    }

    private func removePersistedTrack(_ id: UUID) {
        persistQueue(persistedQueueIDs().filter { $0 != id })
    }

    private func clearPersistedQueue() {
        UserDefaults.standard.removeObject(forKey: Self.persistedQueueIDsKey)
    }

    private struct DownloadByteProgress: Sendable {
        let completed: Int64
        let total: Int64
    }

    private func setProgress(_ progress: RemoteDownloadProgress) {
        itemProgress[progress.id] = progress
        if let index = downloadQueue.firstIndex(where: { $0.id == progress.id }) {
            let previousState = downloadQueue[index].state
            downloadQueue[index] = progress
            if previousState != progress.state { prioritizeDownloadQueue() }
        } else {
            downloadQueue.append(progress)
            prioritizeDownloadQueue()
        }
    }

    private func removeProgress(_ id: UUID) {
        itemProgress.removeValue(forKey: id)
        downloadQueue.removeAll { $0.id == id }
    }

    private func prioritizeDownloadQueue() {
        downloadQueue.sort { lhs, rhs in
            let lhsActive = lhs.state == .downloading
            let rhsActive = rhs.state == .downloading
            if lhsActive != rhsActive { return lhsActive }
            let lhsQueued = lhs.state == .queued
            let rhsQueued = rhs.state == .queued
            if lhsQueued != rhsQueued { return lhsQueued }
            return false
        }
    }

    private nonisolated static func downloadOne(
        _ track: RemoteTrackItem,
        into root: URL,
        replacingExisting: Bool,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws -> DownloadResult {
        guard let scheme = track.streamURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RemoteDownloadError.invalidURL
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: track.streamURL)
        guard let http = response as? HTTPURLResponse else { throw RemoteDownloadError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RemoteDownloadError.httpStatus(http.statusCode) }

        let extensionName = Self.fileExtension(for: response, fallback: track.streamURL.pathExtension)
        let destination = Self.destinationURL(for: track, in: root, extensionName: extensionName)
        let directory = destination.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(".resonance-\(UUID().uuidString).part")
        let expectedBytes = max(0, max(response.expectedContentLength, track.fileSizeBytes))
        var completedBytes: Int64 = 0

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: temporaryURL)
            defer { try? handle.close() }

            var buffer = Data()
            buffer.reserveCapacity(256 * 1024)
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 256 * 1024 {
                    try handle.write(contentsOf: buffer)
                    completedBytes += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progress(completedBytes, expectedBytes)
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                completedBytes += Int64(buffer.count)
                progress(completedBytes, expectedBytes)
            }
            guard completedBytes > 0 else { throw RemoteDownloadError.emptyResponse }
            try handle.close()

            if FileManager.default.fileExists(atPath: destination.path) {
                guard replacingExisting else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    return DownloadResult(bytes: completedBytes, skipped: true, destination: destination)
                }
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return DownloadResult(bytes: completedBytes, skipped: false, destination: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private nonisolated static func destinationURL(
        for track: RemoteTrackItem,
        in root: URL,
        extensionName: String? = nil
    ) -> URL {
        let artistFolder = Self.safeComponent(track.albumArtist.isEmpty ? track.artist : track.albumArtist)
        let albumFolder = Self.safeComponent(track.album.isEmpty ? "Unknown Album" : track.album)
        let trackNumber = track.trackNumber > 0 ? String(format: "%02d", track.trackNumber) : "00"
        let discPrefix = track.discNumber > 1 ? "D\(track.discNumber)-" : ""
        let ext = extensionName ?? Self.fileExtension(for: nil, fallback: track.streamURL.pathExtension)
        let fileName = Self.safeComponent("\(discPrefix)\(trackNumber) - \(track.title)") + ".\(ext)"
        return root
            .appendingPathComponent(artistFolder, isDirectory: true)
            .appendingPathComponent(albumFolder, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private nonisolated static func fileExtension(for response: URLResponse?, fallback: String) -> String {
        let mime = response?.mimeType?.lowercased() ?? ""
        let mapped: String
        switch mime {
        case "audio/flac", "audio/x-flac": mapped = "flac"
        case "audio/mpeg", "audio/mp3": mapped = "mp3"
        case "audio/mp4", "audio/x-m4a": mapped = "m4a"
        case "audio/aac": mapped = "aac"
        case "audio/wav", "audio/x-wav": mapped = "wav"
        case "audio/aiff", "audio/x-aiff": mapped = "aiff"
        case "audio/ogg", "audio/opus": mapped = "ogg"
        default: mapped = ""
        }
        let candidate = mapped.isEmpty ? fallback.lowercased() : mapped
        return MetadataReader.supportedExtensions.contains(candidate) ? candidate : "mp3"
    }

    private nonisolated static func safeComponent(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r")
        let cleaned = value.unicodeScalars.map { forbidden.contains($0) ? "_" : String($0) }.joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown" : String(trimmed.prefix(180))
    }
}
