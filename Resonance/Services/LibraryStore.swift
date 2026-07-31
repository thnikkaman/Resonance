import Foundation
import UniformTypeIdentifiers

private struct LibraryDocumentInventory: Sendable {
    let urls: [URL]
    let modificationDates: [String: Date]
    let sharedFolderTrackCount: Int
}

private struct CachedLibraryDisplayTrack: Codable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let albumArtist: String
    let album: String
    let trackNumber: Int
    let discNumber: Int
    let releaseYear: Int
    let duration: Double
    let fileURL: URL?
    let artworkKey: String?
    let artworkIsEmbedded: Bool
    let dateAdded: Date
    let sourceByteSize: Int64

    init(_ track: Track, artworkKey: String?) {
        id = track.id
        title = track.title
        artist = track.artist
        albumArtist = track.albumArtist
        album = track.album
        trackNumber = track.trackNumber
        discNumber = track.discNumber
        releaseYear = track.releaseYear
        duration = track.duration
        fileURL = track.fileURL
        self.artworkKey = artworkKey
        artworkIsEmbedded = track.artworkIsEmbedded
        dateAdded = track.dateAdded
        sourceByteSize = track.sourceByteSize
    }

    func track(artworkData: Data?, documentsURL: URL) -> Track {
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
            fileURL: LibraryStore.resolvedLocalURL(fileURL, documentsURL: documentsURL),
            artworkData: artworkData,
            artworkIsEmbedded: artworkIsEmbedded,
            dateAdded: dateAdded,
            sourceByteSize: sourceByteSize
        )
    }
}

private struct CachedLibraryDisplaySnapshot: Codable, Sendable {
    let tracks: [CachedLibraryDisplayTrack]
    let artworkByAlbum: [String: Data]
    let artworkByTrack: [String: Data]

    init(tracks: [CachedLibraryDisplayTrack], artworkByAlbum: [String: Data], artworkByTrack: [String: Data]) {
        self.tracks = tracks
        self.artworkByAlbum = artworkByAlbum
        self.artworkByTrack = artworkByTrack
    }

    private enum CodingKeys: String, CodingKey {
        case tracks
        case artworkByAlbum
        case artworkByTrack
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tracks = try container.decode([CachedLibraryDisplayTrack].self, forKey: .tracks)
        artworkByAlbum = try container.decode([String: Data].self, forKey: .artworkByAlbum)
        artworkByTrack = try container.decodeIfPresent([String: Data].self, forKey: .artworkByTrack) ?? [:]
    }
}

@MainActor
final class LibraryStore: ObservableObject {
    static let sharedMusicFolderName = "Resonance Music"

    @Published private(set) var tracks: [Track] = [] {
        didSet {
            invalidateBrowseCaches()
            browseRevision &+= 1
        }
    }
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var grouping: LibraryGrouping = .artists
    @Published var sortDirection: SortDirection = .ascending
    @Published private(set) var lastSharedFolderScan: Date?
    @Published private(set) var sharedFolderTrackCount = 0
    @Published private(set) var sharedFolderIsReady = false
    @Published private(set) var isBootstrapping = true
    @Published private(set) var scanStatus = "Waiting for first scan"
    @Published private(set) var favoriteTrackIDs: Set<UUID> = []
    @Published private(set) var recentPlayDates: [UUID: Date] = [:]
    @Published private(set) var playlists: [UserPlaylist] = []
    @Published private(set) var metadataOverrides: [UUID: TrackMetadataOverride] = [:] {
        didSet {
            invalidateBrowseCaches()
            browseRevision &+= 1
        }
    }
    @Published private(set) var artistMetadataOverrides: [String: ArtistMetadataOverride] = [:] {
        didSet {
            invalidateBrowseCaches()
            browseRevision &+= 1
        }
    }
    @Published private(set) var browseRevision = 0

    private let database = LibraryDatabase()
    private let reader = MetadataReader()
    private var ignoredLocalPaths: Set<String> = []
    private var knownModificationDates: [String: Date] = [:]
    private var didBootstrap = false
    private var lastActiveRefresh: Date?
    private var displaySnapshotDeferralDepth = 0
    private var displaySnapshotDirty = false
    private var displaySnapshotWriteTask: Task<Void, Never>?
    private var cachedFilteredTracks: [String: [Track]] = [:]
    private var cachedArtists: [String: [Artist]] = [:]
    private var cachedAlbums: [String: [Album]] = [:]

    private nonisolated static let displaySnapshotURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("library-display-cache.json")
    }()

    private nonisolated static let displayArtworkDirectoryURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("LibraryDisplayArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private nonisolated static let maximumLegacyDisplaySnapshotBytes: Int64 = 25 * 1_048_576
    private static let artworkRecoveryCompletedKey = "resonance.localArtworkRecovery.v1"

    private enum PersistenceKey {
        static let favorites = "resonance.favoriteTrackIDs"
        static let recentPlays = "resonance.recentPlayDates"
        static let playlists = "resonance.playlists"
        static let ignoredLocalPaths = "resonance.ignoredLocalPaths"
    }

    init() {
        favoriteTrackIDs = Self.loadFavoriteIDs()
        recentPlayDates = Self.loadRecentPlayDates()
        playlists = Self.loadPlaylists()
        metadataOverrides = Self.loadMetadataOverrides()
        artistMetadataOverrides = Self.loadArtistMetadataOverrides()
        ignoredLocalPaths = Self.loadIgnoredLocalPaths()
    }

    var filteredTracks: [Track] {
        let key = browseCacheKey("tracks")
        if let cached = cachedFilteredTracks[key] { return cached }
        let base = searchText.isEmpty ? tracks : tracks.filter {
            [$0.title, $0.artist, $0.albumArtist, $0.album].contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        let result = base.sorted {
            let result = $0.title.localizedStandardCompare($1.title) == .orderedAscending
            return sortDirection == .ascending ? result : !result
        }
        cachedFilteredTracks[key] = result
        return result
    }

    var artists: [Artist] {
        cachedArtistsResult(useAlbumArtist: false)
    }

    var albumArtists: [Artist] {
        cachedArtistsResult(useAlbumArtist: true)
    }

    var albums: [Album] {
        let key = browseCacheKey("albums")
        if let cached = cachedAlbums[key] { return cached }
        let allAlbums = makeAlbums(from: tracks, variousAlbumKeys: Self.mixedArtistAlbumKeys(in: tracks))
        let result: [Album]
        if searchText.isEmpty {
            result = allAlbums
        } else {
            result = allAlbums.filter { album in
            album.title.localizedCaseInsensitiveContains(searchText) ||
            album.artist.localizedCaseInsensitiveContains(searchText) ||
            album.tracks.contains { track in
                [track.title, track.artist, track.albumArtist, track.album]
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        }
        cachedAlbums[key] = result
        return result
    }

    var filteredPlaylists: [UserPlaylist] {
        guard !searchText.isEmpty else { return playlists }
        return playlists.filter { playlist in
            if playlist.name.localizedCaseInsensitiveContains(searchText) { return true }
            return tracks(in: playlist.id).contains { track in
                [track.title, track.artist, track.albumArtist, track.album]
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    var favoriteTracks: [Track] {
        filteredTracks.filter { favoriteTrackIDs.contains($0.id) }
    }

    var recentlyAddedTracks: [Track] {
        Array(filteredTracks.sorted { $0.dateAdded > $1.dateAdded }.prefix(100))
    }

    var recentlyPlayedTracks: [Track] {
        let byID = Dictionary(uniqueKeysWithValues: filteredTracks.map { ($0.id, $0) })
        return recentPlayDates
            .sorted { $0.value > $1.value }
            .compactMap { byID[$0.key] }
            .prefix(100)
            .map { $0 }
    }

    var sharedMusicFolderURL: URL {
        documentsURL.appendingPathComponent(Self.sharedMusicFolderName, isDirectory: true)
    }

    var sharedMusicFolderDisplayPath: String {
        "On My iPhone › Resonance Alpha › \(Self.sharedMusicFolderName)"
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        defer { isBootstrapping = false }
        ensureSharedMusicFolder()

        // Publish the persisted display snapshot first. This is the quickest
        // cache path and avoids showing the empty-library indexing state while
        // SQLite and artwork blobs are being reconciled in the background.
        let cachedTracks = await Task.detached(priority: .utility) {
            Self.loadDisplaySnapshot()
        }.value
        if !cachedTracks.isEmpty {
            tracks = cachedTracks.map(applyMetadataOverride)
            let currentTracks = tracks
            knownModificationDates = await Task.detached(priority: .utility) {
                Self.modificationDates(for: currentTracks)
            }.value
            scanStatus = "Cached library ready — \(tracks.count) tracks"

            Task { [weak self] in
                guard let self else { return }
                let stored = await self.database.loadAll(includeArtwork: false).filter { track in
                    guard let url = track.fileURL else { return true }
                    return !self.ignoredLocalPaths.contains(Self.normalizedPathForInventory(url))
                }
                guard !stored.isEmpty else { return }
                self.reconcilePersistedIndex(stored, preservingArtworkFrom: cachedTracks)
                self.knownModificationDates = await Task.detached(priority: .utility) {
                    Self.modificationDates(for: stored)
                }.value
                let hydrated = await self.database.loadAll(includeArtwork: true)
                self.mergeCachedArtwork(from: hydrated)
                self.persistDisplaySnapshot()
            }
            scheduleArtworkRecoveryIfNeeded()
            return
        }

        // If the display snapshot is absent, use the lightweight database
        // index before falling back to a real Documents scan.
        let stored = await database.loadAll(includeArtwork: false).filter { track in
            guard let url = track.fileURL else { return true }
            return !ignoredLocalPaths.contains(Self.normalizedPathForInventory(url))
        }
        if !stored.isEmpty {
            tracks = stored.map(applyMetadataOverride)
            persistDisplaySnapshot()
            knownModificationDates = await Task.detached(priority: .utility) {
                Self.modificationDates(for: stored)
            }.value
            scanStatus = "Cached library ready — \(tracks.count) tracks"
            scheduleArtworkRecoveryIfNeeded()
            return
        }

        // There is no persisted library to trust on first launch, so the
        // initial scan is still required to discover transferred files.
        await scanDocuments(forceMetadataRefresh: false)
        tracks = Self.demoTracks
        scanStatus = "Shared folder ready — no transferred music found"
    }

    private func reconcilePersistedIndex(
        _ stored: [Track],
        preservingArtworkFrom cachedTracks: [Track]
    ) {
        let cachedByID = Dictionary(uniqueKeysWithValues: cachedTracks.map { ($0.id, $0) })
        tracks = stored.map { storedTrack in
            var merged = applyMetadataOverride(storedTrack)
            if let cached = cachedByID[storedTrack.id], let artworkData = cached.artworkData {
                merged.artworkData = artworkData
                merged.artworkIsEmbedded = cached.artworkIsEmbedded
            }
            return merged
        }
        scanStatus = "Cached library ready — \(tracks.count) tracks"
    }

    private func mergeCachedArtwork(from cachedTracks: [Track]) {
        let artworkByID = Dictionary(
            uniqueKeysWithValues: cachedTracks.compactMap { track -> (UUID, (Data, Bool))? in
                guard let artworkData = track.artworkData else { return nil }
                return (track.id, (artworkData, track.artworkIsEmbedded))
            }
        )
        guard !artworkByID.isEmpty else { return }
        tracks = tracks.map { track in
            guard let (artworkData, artworkIsEmbedded) = artworkByID[track.id] else {
                return track
            }
            guard track.artworkData != artworkData || track.artworkIsEmbedded != artworkIsEmbedded else {
                return track
            }
            var hydrated = track
            hydrated.artworkData = artworkData
            hydrated.artworkIsEmbedded = artworkIsEmbedded
            return hydrated
        }
    }

    private func scheduleArtworkRecoveryIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.artworkRecoveryCompletedKey) else { return }
        guard tracks.contains(where: { $0.artworkIsEmbedded && $0.artworkData == nil }) else {
            UserDefaults.standard.set(true, forKey: Self.artworkRecoveryCompletedKey)
            return
        }

        scanStatus = "Recovering embedded artwork…"
        ResonanceDiagnostics.shared.recordDeferred("library.artworkRecovery.begin")
        Task { [weak self] in
            guard let self else { return }
            await self.scanDocuments(forceMetadataRefresh: true)
            UserDefaults.standard.set(true, forKey: Self.artworkRecoveryCompletedKey)
            ResonanceDiagnostics.shared.recordDeferred("library.artworkRecovery.complete")
        }
    }

    func refreshForActiveState() async {
        if didBootstrap {
            // Startup and foreground transitions use the cached database.
            // Explicit Library/Settings scan controls handle rare file changes.
            return
        } else {
            await bootstrap()
        }
    }

    func scanSharedMusicFolder(forceMetadataRefresh: Bool = true) async {
        ensureSharedMusicFolder()
        await scanDocuments(forceMetadataRefresh: forceMetadataRefresh)
    }

    func refreshDownloadedTrack(at url: URL) async {
        guard MetadataReader.supportedExtensions.contains(url.pathExtension.lowercased()) else { return }
        // Download finalization already knows the destination inside the app's
        // Documents folder. Resolving symlinks here performs synchronous file
        // system work on the main actor and can trip the iOS watchdog while a
        // large background batch is completing.
        let path = normalizedDownloadPath(url)
        guard let parsed = await reader.track(from: url) else { return }
        let existingIndex = tracks.firstIndex { track in
            guard let fileURL = track.fileURL else { return false }
            return normalizedDownloadPath(fileURL) == path
        }
        let existing = existingIndex.map { tracks[$0] }
        let refreshed = applyMetadataOverride(preservingIdentity(of: parsed, existing: existing))

        if let existingIndex {
            tracks[existingIndex] = refreshed
        } else {
            tracks.append(refreshed)
            sharedFolderTrackCount += 1
        }
        ignoredLocalPaths.remove(path)
        persistIgnoredLocalPaths()
        knownModificationDates[path] = modificationDate(for: url)
        cleanPersistedCollections()
        await database.upsert(refreshed)
        persistDisplaySnapshot()
        lastSharedFolderScan = Date()
        scanStatus = "Indexed \(tracks.count) track\(tracks.count == 1 ? "" : "s")"
    }

    func beginDisplaySnapshotDeferral() {
        displaySnapshotDeferralDepth += 1
    }

    func endDisplaySnapshotDeferral() {
        displaySnapshotDeferralDepth = max(0, displaySnapshotDeferralDepth - 1)
        guard displaySnapshotDeferralDepth == 0, displaySnapshotDirty else { return }
        persistDisplaySnapshot()
    }

    func importURLs(_ urls: [URL]) async {
        ensureSharedMusicFolder()
        isScanning = true
        scanStatus = "Copying selected music…"
        defer { isScanning = false }
        var importedURLs: [URL] = []

        for selectedURL in urls {
            let accessed = selectedURL.startAccessingSecurityScopedResource()
            defer { if accessed { selectedURL.stopAccessingSecurityScopedResource() } }

            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory)
            let sources = isDirectory.boolValue ? expandDirectory(selectedURL) : [selectedURL]
            let destinationRoot = isDirectory.boolValue
                ? sharedMusicFolderURL.appendingPathComponent(selectedURL.lastPathComponent, isDirectory: true)
                : sharedMusicFolderURL

            for source in sources {
                guard MetadataReader.supportedExtensions.contains(source.pathExtension.lowercased()) else { continue }
                let relativePath = isDirectory.boolValue
                    ? source.path.replacingOccurrences(of: selectedURL.path + "/", with: "")
                    : source.lastPathComponent
                let target = destinationRoot.appendingPathComponent(relativePath)

                do {
                    try FileManager.default.createDirectory(
                        at: target.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    ignoredLocalPaths.remove(normalizedPath(target))
                    if !FileManager.default.fileExists(atPath: target.path) {
                        try FileManager.default.copyItem(at: source, to: target)
                    }
                    importedURLs.append(target)
                } catch {
                    continue
                }
            }
        }

        isScanning = false
        persistIgnoredLocalPaths()
        for url in importedURLs {
            await refreshDownloadedTrack(at: url)
        }
    }

    func isFavorite(_ track: Track) -> Bool {
        favoriteTrackIDs.contains(track.id)
    }

    func toggleFavorite(_ track: Track) {
        if favoriteTrackIDs.contains(track.id) {
            favoriteTrackIDs.remove(track.id)
        } else {
            favoriteTrackIDs.insert(track.id)
        }
        persistFavorites()
    }

    func isAlbumFavorite(_ album: Album) -> Bool {
        !album.tracks.isEmpty && album.tracks.allSatisfy { favoriteTrackIDs.contains($0.id) }
    }

    func toggleFavorite(_ album: Album) {
        let ids = Set(album.tracks.map(\.id))
        if ids.isSubset(of: favoriteTrackIDs) {
            favoriteTrackIDs.subtract(ids)
        } else {
            favoriteTrackIDs.formUnion(ids)
        }
        persistFavorites()
    }

    func markPlayed(_ track: Track) {
        recentPlayDates[track.id] = Date()
        if recentPlayDates.count > 250 {
            let retained = recentPlayDates.sorted { $0.value > $1.value }.prefix(200)
            recentPlayDates = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
        persistRecentPlays()
    }

    @discardableResult
    func createPlaylist(named rawName: String) -> UUID? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let playlist = UserPlaylist(name: name)
        playlists.append(playlist)
        playlists.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persistPlaylists()
        return playlist.id
    }

    func renamePlaylist(_ playlistID: UUID, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].name = name
        playlists[index].modifiedAt = Date()
        playlists.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persistPlaylists()
    }

    func deletePlaylist(_ playlistID: UUID) {
        playlists.removeAll { $0.id == playlistID }
        persistPlaylists()
    }

    func add(_ track: Track, to playlistID: UUID) {
        _ = add([track], to: playlistID)
    }

    @discardableResult
    func add(_ tracksToAdd: [Track], to playlistID: UUID) -> Int {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return 0 }
        var existingIDs = Set(playlists[index].trackIDs)
        let newIDs = tracksToAdd.map(\.id).filter { existingIDs.insert($0).inserted }
        guard !newIDs.isEmpty else { return 0 }
        playlists[index].trackIDs.append(contentsOf: newIDs)
        playlists[index].modifiedAt = Date()
        persistPlaylists()
        return newIDs.count
    }

    func remove(_ track: Track, from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll { $0 == track.id }
        playlists[index].modifiedAt = Date()
        persistPlaylists()
    }

    func moveTracks(in playlistID: UUID, from offsets: IndexSet, to destination: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        var ids = playlists[index].trackIDs
        let validOffsets = offsets.filter { ids.indices.contains($0) }.sorted()
        let moving = validOffsets.map { ids[$0] }
        for offset in validOffsets.reversed() { ids.remove(at: offset) }
        let removedBeforeDestination = validOffsets.filter { $0 < destination }.count
        let insertionIndex = max(0, min(ids.count, destination - removedBeforeDestination))
        ids.insert(contentsOf: moving, at: insertionIndex)
        playlists[index].trackIDs = ids
        playlists[index].modifiedAt = Date()
        persistPlaylists()
    }

    func playlist(id: UUID) -> UserPlaylist? {
        playlists.first { $0.id == id }
    }

    func tracks(in playlistID: UUID) -> [Track] {
        guard let playlist = playlist(id: playlistID) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return playlist.trackIDs.compactMap { byID[$0] }
    }

    func artworkData(for track: Track) -> Data? {
        track.artworkData
    }

    func artworkIsEmbedded(for track: Track) -> Bool {
        track.artworkIsEmbedded
    }

    func hasMetadataOverride(_ track: Track) -> Bool {
        metadataOverrides[track.id] != nil
    }

    func applyArtworkToApp(for trackID: UUID, data: Data) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        objectWillChange.send()
        var override = metadataOverrides[trackID] ?? TrackMetadataOverride()
        override.artworkData = data
        override.hasArtworkOverride = true
        metadataOverrides[trackID] = override
        tracks[index] = override.applying(to: tracks[index])
        persistMetadataOverrides()
    }

    func writeArtworkToFile(at url: URL, from track: Track, data: Data) async -> Bool {
        guard !data.isEmpty else { return false }
        let values = MetadataTagValues(
            title: track.title,
            artist: track.artist,
            albumArtist: track.albumArtist,
            album: track.album,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            releaseYear: track.releaseYear
        )
        do {
            try await Task.detached(priority: .utility) {
                try MetadataTagWriter.write(
                    to: url,
                    values: values,
                    artworkData: data,
                    replaceArtwork: true
                )
            }.value
            return true
        } catch {
            ResonanceDiagnostics.shared.recordDeferred(
                "download.artworkEmbed.failed",
                details: ["format": url.pathExtension.lowercased()]
            )
            return false
        }
    }

    func applyArtworkToApp(forAlbumTrackIDs trackIDs: [UUID], data: Data) {
        objectWillChange.send()
        for trackID in trackIDs {
            guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { continue }
            var override = metadataOverrides[trackID] ?? TrackMetadataOverride()
            override.artworkData = data
            override.hasArtworkOverride = true
            metadataOverrides[trackID] = override
            tracks[index] = override.applying(to: tracks[index])
        }
        persistMetadataOverrides()
    }

    func applyArtworkToApp(for artist: Artist, data: Data) {
        let key = artistOverrideKey(name: artist.name, useAlbumArtist: artist.usesAlbumArtist)
        objectWillChange.send()
        artistMetadataOverrides[key] = ArtistMetadataOverride(artworkData: data, hasArtworkOverride: true)
        persistArtistMetadataOverrides()
    }

    func updateTrackMetadata(
        trackID: UUID,
        title: String,
        artist: String,
        albumArtist: String,
        album: String,
        trackNumber: Int,
        discNumber: Int,
        releaseYear: Int,
        artworkData: Data?,
        replaceArtwork: Bool
    ) async -> String? {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else {
            return "The selected track is no longer in the local library."
        }
        let track = tracks[index]
        guard let url = track.fileURL, !track.isRemote else {
            return "Metadata tags can only be edited on local files."
        }

        let values = MetadataTagValues(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            albumArtist: albumArtist.trimmingCharacters(in: .whitespacesAndNewlines),
            album: album.trimmingCharacters(in: .whitespacesAndNewlines),
            trackNumber: max(0, trackNumber),
            discNumber: max(1, discNumber),
            releaseYear: max(0, releaseYear)
        )
        let result = await MetadataWriteBatch.write([
            MetadataWriteRequest(
                id: trackID,
                url: url,
                values: values,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
        ])
        if let failure = result.failures.first { return failure }

        metadataOverrides.removeValue(forKey: trackID)
        persistMetadataOverrides()
        ResonanceDiagnostics.shared.recordDeferred(
            "library.metadata.trackSave",
            details: [
                "writableCount": "1",
                "failureCount": "0",
                "extension": url.pathExtension.lowercased()
            ]
        )
        await refreshMetadataFiles(from: result, requests: [
            MetadataWriteRequest(
                id: trackID,
                url: url,
                values: values,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
        ])
        return nil
    }

    func updateTrackMetadataInBackground(
        trackID: UUID,
        title: String,
        artist: String,
        albumArtist: String,
        album: String,
        trackNumber: Int,
        discNumber: Int,
        releaseYear: Int,
        artworkData: Data?,
        replaceArtwork: Bool
    ) {
        Task { [weak self] in
            guard let self else { return }
            let error = await self.updateTrackMetadata(
                trackID: trackID,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                trackNumber: trackNumber,
                discNumber: discNumber,
                releaseYear: releaseYear,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
            ResonanceDiagnostics.shared.recordDeferred(
                "library.metadata.trackSave.complete",
                details: [
                    "success": String(error == nil),
                    "failureCount": error == nil ? "0" : "1"
                ]
            )
        }
    }

    func refreshedArtist(_ artist: Artist) -> Artist {
        let currentTracks = tracks.filter { track in
            let currentName = artist.usesAlbumArtist ? track.albumArtist : track.artist
            return currentName.localizedCaseInsensitiveCompare(artist.name) == .orderedSame
        }
        guard let first = currentTracks.first else { return artist }
        let currentName = artist.usesAlbumArtist ? first.albumArtist : first.artist
        return makeArtist(
            name: currentName,
            tracks: currentTracks,
            useAlbumArtist: artist.usesAlbumArtist,
            variousAlbumKeys: Self.mixedArtistAlbumKeys(in: tracks)
        )
    }

    func updateArtistMetadata(
        artist: Artist,
        name: String,
        artworkData: Data?,
        replaceArtwork: Bool,
        clearArtworkOverride: Bool
    ) async -> String? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return "Enter an artist name." }

        let ids = Set(artist.albums.flatMap(\.tracks).map(\.id))
        guard !ids.isEmpty else { return "The selected artist has no tracks." }
        let oldName = artist.name
        let shouldRewriteTags = oldName.localizedCaseInsensitiveCompare(cleanedName) != .orderedSame
        let requests = shouldRewriteTags ? tracks.compactMap { track -> MetadataWriteRequest? in
            guard ids.contains(track.id), let url = track.fileURL, !track.isRemote else { return nil }
            let updatedArtist = artist.usesAlbumArtist ? track.artist : cleanedName
            let updatedAlbumArtist = artist.usesAlbumArtist
                ? cleanedName
                : (track.albumArtist.localizedCaseInsensitiveCompare(oldName) == .orderedSame ? cleanedName : track.albumArtist)
            let values = MetadataTagValues(
                title: track.title,
                artist: updatedArtist,
                albumArtist: updatedAlbumArtist,
                album: track.album,
                trackNumber: track.trackNumber,
                discNumber: track.discNumber,
                releaseYear: track.releaseYear
            )
            return MetadataWriteRequest(
                id: track.id,
                url: url,
                values: values,
                // Artist artwork is an app-level artist override. It must not
                // be copied into every song in the artist's catalog.
                artworkData: nil,
                replaceArtwork: false
            )
        } : []
        let writeResult = await MetadataWriteBatch.write(requests)
        let writableIDs = writeResult.successfulIDs
        let failures = writeResult.failures

        let oldKey = artistOverrideKey(name: oldName, useAlbumArtist: artist.usesAlbumArtist)
        let newKey = artistOverrideKey(name: cleanedName, useAlbumArtist: artist.usesAlbumArtist)

        objectWillChange.send()
        let previousOverride = artistMetadataOverrides[oldKey]
        artistMetadataOverrides.removeValue(forKey: oldKey)
        artistMetadataOverrides.removeValue(forKey: newKey)
        if clearArtworkOverride {
            // The explicit remove action wins over a rename or an existing
            // fallback image.
        } else if let artworkData, replaceArtwork {
            artistMetadataOverrides[newKey] = ArtistMetadataOverride(
                artworkData: artworkData,
                hasArtworkOverride: true
            )
        } else if let previousOverride {
            // Renaming an artist should not orphan its artist-only artwork.
            artistMetadataOverrides[newKey] = previousOverride
        }

        for id in writableIDs { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        persistArtistMetadataOverrides()
        await refreshMetadataFiles(from: writeResult, requests: requests)
        return failures.isEmpty ? nil : failures.first
    }

    func updateArtistMetadataInBackground(
        artist: Artist,
        name: String,
        artworkData: Data?,
        replaceArtwork: Bool,
        clearArtworkOverride: Bool
    ) {
        Task { [weak self] in
            guard let self else { return }
            let error = await self.updateArtistMetadata(
                artist: artist,
                name: name,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork,
                clearArtworkOverride: clearArtworkOverride
            )
            ResonanceDiagnostics.shared.recordDeferred(
                "library.metadata.artistSave.complete",
                details: [
                    "success": String(error == nil),
                    "failureCount": error == nil ? "0" : "1"
                ]
            )
        }
    }

    func updateAlbumMetadata(
        trackIDs: [UUID],
        album: String,
        albumArtist: String,
        releaseYear: Int,
        artworkData: Data?,
        replaceArtwork: Bool
    ) async -> String? {
        let ids = Set(trackIDs)
        guard !ids.isEmpty else { return "The selected album has no tracks." }
        let requests = tracks.compactMap { track -> MetadataWriteRequest? in
            guard ids.contains(track.id), let url = track.fileURL, !track.isRemote else { return nil }
            let values = MetadataTagValues(
                title: track.title,
                artist: track.artist,
                albumArtist: albumArtist.trimmingCharacters(in: .whitespacesAndNewlines),
                album: album.trimmingCharacters(in: .whitespacesAndNewlines),
                trackNumber: track.trackNumber,
                discNumber: track.discNumber,
                releaseYear: max(0, releaseYear)
            )
            return MetadataWriteRequest(
                id: track.id,
                url: url,
                values: values,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
        }
        let writeResult = await MetadataWriteBatch.write(requests)
        let writableIDs = writeResult.successfulIDs
        let failures = writeResult.failures

        let preservingArtworkOverride = replaceArtwork && artworkData != nil
        ResonanceDiagnostics.shared.recordDeferred(
            "library.metadata.albumSave",
            details: [
                "trackCount": String(ids.count),
                "writableCount": String(writableIDs.count),
                "failureCount": String(failures.count),
                "preservingArtworkOverride": String(preservingArtworkOverride)
            ]
        )

        if writableIDs.isEmpty, let artworkData, replaceArtwork, failures.isEmpty {
            applyArtworkToApp(forAlbumTrackIDs: Array(ids), data: artworkData)
            return nil
        }

        // Artwork saved to the audio file is confirmed file artwork, not an
        // app-only suggestion. Removing sidecar overrides lets the targeted
        // reread mark the embedded image as authoritative.
        for id in writableIDs { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        await refreshMetadataFiles(from: writeResult, requests: requests)
        return failures.isEmpty ? nil : failures.first
    }

    /// Starts an album metadata save without making the editor wait for every
    /// file and artwork block to finish. The individual writes remain
    /// sequential and the targeted read-back still updates the library.
    func updateAlbumMetadataInBackground(
        trackIDs: [UUID],
        album: String,
        albumArtist: String,
        releaseYear: Int,
        artworkData: Data?,
        replaceArtwork: Bool
    ) {
        Task { [weak self] in
            guard let self else { return }
            let error = await self.updateAlbumMetadata(
                trackIDs: trackIDs,
                album: album,
                albumArtist: albumArtist,
                releaseYear: releaseYear,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
            ResonanceDiagnostics.shared.recordDeferred(
                "library.metadata.albumSave.complete",
                details: [
                    "success": String(error == nil),
                    "failureCount": error == nil ? "0" : "1"
                ]
            )
        }
    }

    /// Metadata saves already know exactly which files were written. Reread
    /// those files only; a full Documents rescan can otherwise keep the editor
    /// in its Saving state while thousands of unrelated tracks are parsed.
    private func refreshMetadataFiles(
        from result: MetadataWriteBatchResult,
        requests: [MetadataWriteRequest]
    ) async {
        for request in requests where result.successfulIDs.contains(request.id) {
            await refreshDownloadedTrack(at: request.url)
        }
    }

    func resetMetadataOverrides(for trackIDs: [UUID]) async {
        let ids = Set(trackIDs)
        for id in ids { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        // The affected files are already known; reread only those tracks
        // instead of forcing a full-library metadata scan.
        let affectedURLs = tracks.compactMap { track -> URL? in
            guard ids.contains(track.id), let url = track.fileURL, !track.isRemote else { return nil }
            return url
        }
        for url in affectedURLs {
            await refreshDownloadedTrack(at: url)
        }
    }

    func removeArtist(_ artist: Artist, deletingFiles: Bool) async {
        let ids = Set(artist.albums.flatMap(\.tracks).map(\.id))
        await removeTracks(tracks.filter { ids.contains($0.id) }, deletingFiles: deletingFiles)
        artistMetadataOverrides.removeValue(
            forKey: artistOverrideKey(name: artist.name, useAlbumArtist: artist.usesAlbumArtist)
        )
        persistArtistMetadataOverrides()
    }

    func removeTracks(_ tracksToRemove: [Track], deletingFiles: Bool) async {
        let ids = Set(tracksToRemove.map(\.id))
        let removed = tracks.filter { ids.contains($0.id) }
        tracks.removeAll { ids.contains($0.id) }
        favoriteTrackIDs.subtract(ids)
        recentPlayDates = recentPlayDates.filter { !ids.contains($0.key) }
        metadataOverrides = metadataOverrides.filter { !ids.contains($0.key) }
        for index in playlists.indices {
            playlists[index].trackIDs.removeAll { ids.contains($0) }
        }
        persistFavorites()
        persistRecentPlays()
        persistPlaylists()
        persistMetadataOverrides()
        var deletedCount = 0
        var failedDeleteCount = 0
        var missingCount = 0
        for track in removed {
            guard let url = track.fileURL else { continue }
            let path = normalizedPath(url)
            if deletingFiles {
                ignoredLocalPaths.remove(path)
                if !FileManager.default.fileExists(atPath: url.path) {
                    missingCount += 1
                } else {
                    do {
                        try FileManager.default.removeItem(at: url)
                        deletedCount += 1
                    } catch {
                        failedDeleteCount += 1
                    }
                }
            } else {
                ignoredLocalPaths.insert(path)
            }
        }
        if deletingFiles {
            ResonanceDiagnostics.shared.recordDeferred(
                "library.fileDelete",
                details: [
                    "requested": String(removed.filter { $0.fileURL != nil }.count),
                    "deleted": String(deletedCount),
                    "missing": String(missingCount),
                    "failed": String(failedDeleteCount)
                ]
            )
        }
        persistIgnoredLocalPaths()
        let persistedIDs = Set(removed.filter { $0.fileURL != nil }.map(\.id))
        await database.delete(ids: persistedIDs)
        persistDisplaySnapshot()
    }

    func resetDemoLibrary() async {
        tracks = Self.demoTracks
        await database.replaceAll(with: [])
        try? FileManager.default.removeItem(at: Self.displaySnapshotURL)
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func persistDisplaySnapshot() {
        displaySnapshotDirty = true
        guard displaySnapshotDeferralDepth == 0 else { return }

        var cachedTracks: [CachedLibraryDisplayTrack] = []
        var artworkRecords: [(key: String, data: Data)] = []
        cachedTracks.reserveCapacity(tracks.count)

        for track in tracks {
            let artworkKey: String?
            if let artworkData = track.artworkData, !artworkData.isEmpty {
                let trackKey = track.id.uuidString
                artworkRecords.append((key: trackKey, data: artworkData))
                artworkKey = trackKey
            } else {
                artworkKey = nil
            }
            cachedTracks.append(CachedLibraryDisplayTrack(track, artworkKey: artworkKey))
        }

        let snapshot = CachedLibraryDisplaySnapshot(
            tracks: cachedTracks,
            artworkByAlbum: [:],
            artworkByTrack: [:]
        )
        let destination = Self.displaySnapshotURL
        let artworkDirectory = Self.displayArtworkDirectoryURL
        displaySnapshotWriteTask?.cancel()
        displaySnapshotWriteTask = Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
            for record in artworkRecords {
                guard !Task.isCancelled else { return }
                let artworkURL = artworkDirectory.appendingPathComponent(record.key).appendingPathExtension("data")
                try? record.data.write(to: artworkURL, options: .atomic)
            }
            guard !Task.isCancelled, let encoded = try? JSONEncoder().encode(snapshot) else { return }
            try? encoded.write(to: destination, options: .atomic)
        }
        displaySnapshotDirty = false
    }

    fileprivate nonisolated static func resolvedLocalURL(_ url: URL?, documentsURL: URL) -> URL? {
        guard let url, url.isFileURL else { return url }

        // Cached snapshots historically stored absolute URLs. An in-place app
        // update can change the container UUID while preserving Documents, so
        // restore files beneath the current Documents directory instead of
        // trusting the stale container component.
        let path = url.standardizedFileURL.path
        let marker = "/Documents/"
        guard let range = path.range(of: marker) else { return url }
        let relativePath = String(path[range.upperBound...])
        return documentsURL.appendingPathComponent(relativePath)
    }

    private nonisolated static func loadDisplaySnapshot() -> [Track] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: displaySnapshotURL.path),
              let byteCount = attributes[.size] as? NSNumber,
              byteCount.int64Value <= maximumLegacyDisplaySnapshotBytes,
              let data = try? Data(contentsOf: displaySnapshotURL),
              let snapshot = try? JSONDecoder().decode(CachedLibraryDisplaySnapshot.self, from: data)
        else { return [] }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return snapshot.tracks.map { cached in
            let sidecarArtwork = cached.artworkKey.flatMap { key -> Data? in
                let url = displayArtworkDirectoryURL
                    .appendingPathComponent(key)
                    .appendingPathExtension("data")
                return try? Data(contentsOf: url)
            }
            return cached.track(
                artworkData: sidecarArtwork
                    ?? cached.artworkKey.flatMap { snapshot.artworkByTrack[$0] ?? snapshot.artworkByAlbum[$0] },
                documentsURL: documentsURL
            )
        }
    }

    private func ensureSharedMusicFolder() {
        do {
            try FileManager.default.createDirectory(
                at: sharedMusicFolderURL,
                withIntermediateDirectories: true
            )
            sharedFolderIsReady = true
        } catch {
            sharedFolderIsReady = false
            scanStatus = "Could not create the shared music folder"
        }
    }

    private func scanDocuments(forceMetadataRefresh: Bool) async {
        guard !isScanning else { return }
        let hadExistingContent = !tracks.isEmpty
        // Keep the scan gate active even when cached content is already
        // visible. Previously this was false for an existing library, so a
        // second refresh could start another full metadata scan concurrently.
        isScanning = true
        scanStatus = hadExistingContent ? "Checking transferred music…" : "Scanning transferred music…"
        let scanStarted = Date()
        ResonanceDiagnostics.shared.recordDeferred(
            "library.scan.begin",
            details: [
                "forceMetadataRefresh": String(forceMetadataRefresh),
                "existingTrackCount": String(tracks.count),
                "contentVisible": String(hadExistingContent)
            ]
        )
        defer { isScanning = false }

        let documentsURL = self.documentsURL
        let sharedRootPath = sharedMusicFolderURL.standardizedFileURL.path + "/"
        let ignoredPaths = ignoredLocalPaths
        let inventory = await Task.detached(priority: .utility) {
            Self.collectDocumentInventory(
                documentsURL: documentsURL,
                sharedFolderPath: sharedRootPath,
                ignoredPaths: ignoredPaths
            )
        }.value
        let urls = inventory.urls
        sharedFolderTrackCount = inventory.sharedFolderTrackCount

        let currentPaths = Set(urls.map(normalizedPath))
        let existingByPath = Dictionary(
            uniqueKeysWithValues: tracks.compactMap { track -> (String, Track)? in
                guard let url = track.fileURL else { return nil }
                return (normalizedPath(url), track)
            }
        )

        let knownPaths = Set(existingByPath.keys)
        let modificationsChanged = inventory.modificationDates.contains { path, modified in
            knownModificationDates[path] != modified
        }
        let needsRefresh = forceMetadataRefresh || currentPaths != knownPaths || modificationsChanged

        ResonanceDiagnostics.shared.recordDeferred(
            "library.scan.inventory",
            details: [
                "fileCount": String(urls.count),
                "needsRefresh": String(needsRefresh),
                "durationMs": String(format: "%.1f", Date().timeIntervalSince(scanStarted) * 1000)
            ]
        )

        guard needsRefresh else {
            lastSharedFolderScan = Date()
            scanStatus = "Up to date — \(sharedFolderTrackCount) file\(sharedFolderTrackCount == 1 ? "" : "s") in \(Self.sharedMusicFolderName)"
            ResonanceDiagnostics.shared.recordDeferred(
                "library.scan.complete",
                details: [
                    "result": "unchanged",
                    "trackCount": String(tracks.count),
                    "durationMs": String(format: "%.1f", Date().timeIntervalSince(scanStarted) * 1000)
                ]
            )
            return
        }

        var refreshed: [Track] = []
        let newModificationDates = inventory.modificationDates

        for url in urls {
            let path = normalizedPath(url)
            let modified = newModificationDates[path] ?? .distantPast
            let existing = existingByPath[path]
            let changed = knownModificationDates[path] != modified

            if !forceMetadataRefresh, !changed, let existing {
                refreshed.append(existing)
                continue
            }

            if let parsed = await reader.track(from: url) {
                refreshed.append(applyMetadataOverride(preservingIdentity(of: parsed, existing: existing)))
            } else if let existing {
                refreshed.append(existing)
            }
        }

        knownModificationDates = newModificationDates
        tracks = deduplicate(refreshed)
        cleanPersistedCollections()
        await database.replaceAll(with: tracks)
        persistDisplaySnapshot()
        lastSharedFolderScan = Date()
        scanStatus = "Indexed \(tracks.count) track\(tracks.count == 1 ? "" : "s")"
        ResonanceDiagnostics.shared.recordDeferred(
            "library.scan.complete",
            details: [
                "result": "indexed",
                "trackCount": String(tracks.count),
                "durationMs": String(format: "%.1f", Date().timeIntervalSince(scanStarted) * 1000)
            ]
        )
    }

    private nonisolated static func modificationDates(for tracks: [Track]) -> [String: Date] {
        var result: [String: Date] = [:]
        result.reserveCapacity(tracks.count)
        for track in tracks {
            guard let url = track.fileURL, !track.isRemote else { continue }
            let path = normalizedPathForInventory(url)
            result[path] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
        }
        return result
    }

    private nonisolated static func collectDocumentInventory(
        documentsURL: URL,
        sharedFolderPath: String,
        ignoredPaths: Set<String>
    ) -> LibraryDocumentInventory {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        let urls = (enumerator?.allObjects as? [URL] ?? [])
            .filter { url in
                guard MetadataReader.supportedExtensions.contains(url.pathExtension.lowercased()) else {
                    return false
                }
                guard !ignoredPaths.contains(normalizedPathForInventory(url)) else { return false }
                return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        var modificationDates: [String: Date] = [:]
        modificationDates.reserveCapacity(urls.count)
        for url in urls {
            modificationDates[normalizedPathForInventory(url)] =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
        }

        let sharedFolderTrackCount = urls.reduce(into: 0) { count, url in
            if url.standardizedFileURL.path.hasPrefix(sharedFolderPath) {
                count += 1
            }
        }
        return LibraryDocumentInventory(
            urls: urls,
            modificationDates: modificationDates,
            sharedFolderTrackCount: sharedFolderTrackCount
        )
    }

    private nonisolated static func normalizedPathForInventory(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func preservingIdentity(of parsed: Track, existing: Track?) -> Track {
        guard let existing else { return parsed }
        let artworkData = parsed.artworkData
            ?? existing.artworkData.flatMap { MetadataReader.renderableArtworkData(from: $0) }
        return Track(
            id: existing.id,
            title: parsed.title,
            artist: parsed.artist,
            albumArtist: parsed.albumArtist,
            album: parsed.album,
            trackNumber: parsed.trackNumber,
            discNumber: parsed.discNumber,
            releaseYear: parsed.releaseYear,
            duration: parsed.duration,
            fileURL: parsed.fileURL,
            artworkData: artworkData,
            artworkIsEmbedded: artworkData != nil,
            dateAdded: existing.dateAdded
        )
    }

    private func allDocumentAudioURLs() -> [URL] {
        expandDirectory(documentsURL)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func expandDirectory(_ url: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        return (enumerator?.allObjects as? [URL] ?? []).filter {
            MetadataReader.supportedExtensions.contains($0.pathExtension.lowercased())
        }
    }

    private func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func normalizedDownloadPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func browseCacheKey(_ surface: String) -> String {
        "\(surface)|\(sortDirection.rawValue)|\(searchText)"
    }

    private func invalidateBrowseCaches() {
        cachedFilteredTracks.removeAll(keepingCapacity: true)
        cachedArtists.removeAll(keepingCapacity: true)
        cachedAlbums.removeAll(keepingCapacity: true)
    }

    private func deduplicate(_ input: [Track]) -> [Track] {
        Array(
            Dictionary(
                grouping: input,
                by: { $0.fileURL.map(normalizedPath) ?? $0.id.uuidString }
            ).compactMap(\.value.last)
        )
    }

    private func cachedArtistsResult(useAlbumArtist: Bool) -> [Artist] {
        let key = browseCacheKey(useAlbumArtist ? "album-artists" : "artists")
        if let cached = cachedArtists[key] { return cached }
        let result = makeArtists(useAlbumArtist: useAlbumArtist)
        cachedArtists[key] = result
        return result
    }

    private func makeArtists(useAlbumArtist: Bool) -> [Artist] {
        let variousAlbumKeys = Self.mixedArtistAlbumKeys(in: tracks)
        var groups: [String: (name: String, tracks: [Track])] = [:]
        for track in tracks {
            let isVarious = variousAlbumKeys.contains(LibraryBrowseGrouping.mixedArtistAlbumIdentity(for: track))
            let name = isVarious ? "Various Artists" : (useAlbumArtist ? track.albumArtist : track.artist)
            let key = isVarious ? "various-artists" : "artist|\(name)"
            groups[key, default: (name: name, tracks: [])].tracks.append(track)
        }
        var mapped = groups.values.map { group in
            makeArtist(
                name: group.name,
                tracks: group.tracks,
                useAlbumArtist: useAlbumArtist,
                variousAlbumKeys: variousAlbumKeys
            )
        }
        if !searchText.isEmpty {
            mapped = mapped.filter { artist in
                artist.name.localizedCaseInsensitiveContains(searchText) ||
                artist.albums.flatMap(\.tracks).contains { track in
                    [track.title, track.artist, track.albumArtist, track.album]
                        .contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }
        return mapped.sorted {
            sortDirection == .ascending
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.name.localizedStandardCompare($1.name) == .orderedDescending
        }
    }

    private func makeArtist(
        name: String,
        tracks: [Track],
        useAlbumArtist: Bool,
        variousAlbumKeys: Set<String>
    ) -> Artist {
        let key = artistOverrideKey(name: name, useAlbumArtist: useAlbumArtist)
        let artworkOverride = artistMetadataOverrides[key]
        let hasTrackOverride = tracks.contains { track in
            guard let override = metadataOverrides[track.id] else { return false }
            return useAlbumArtist ? override.albumArtist != nil : override.artist != nil
        }
        return Artist(
            id: key,
            name: name,
            albums: makeAlbums(from: tracks, variousAlbumKeys: variousAlbumKeys),
            usesAlbumArtist: useAlbumArtist,
            customArtworkData: artworkOverride?.artworkData,
            hasArtworkOverride: artworkOverride?.hasArtworkOverride ?? false,
            hasMetadataOverride: hasTrackOverride || artworkOverride != nil
        )
    }

    private func artistOverrideKey(name: String, useAlbumArtist: Bool) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(useAlbumArtist ? "albumArtist" : "artist")|\(normalizedName)"
    }

    private func makeAlbums(from tracks: [Track], variousAlbumKeys: Set<String> = []) -> [Album] {
        Dictionary(grouping: tracks) { track in
            if variousAlbumKeys.contains(LibraryBrowseGrouping.mixedArtistAlbumIdentity(for: track)) {
                return "various|\(LibraryBrowseGrouping.mixedArtistAlbumIdentity(for: track))"
            }
            return "\(track.albumArtist)|\(track.album)"
        }.map { key, values in
            let sorted = values.sorted { ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title) }
            let isVarious = key.hasPrefix("various|")
            return Album(
                id: key,
                title: sorted.first?.album ?? "Unknown Album",
                artist: isVarious ? "Various Artists" : (sorted.first?.albumArtist ?? "Unknown Artist"),
                tracks: sorted
            )
        }.sorted {
            sortDirection == .ascending
                ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                : $0.title.localizedStandardCompare($1.title) == .orderedDescending
        }
    }

    private nonisolated static func mixedArtistAlbumKeys(in tracks: [Track]) -> Set<String> {
        LibraryBrowseGrouping.mixedArtistAlbumKeys(
            in: tracks,
            albumIdentity: LibraryBrowseGrouping.mixedArtistAlbumIdentity,
            artistIdentity: { $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
    }

    private func cleanPersistedCollections() {
        let validIDs = Set(tracks.map(\.id))
        favoriteTrackIDs.formIntersection(validIDs)
        recentPlayDates = recentPlayDates.filter { validIDs.contains($0.key) }
        metadataOverrides = metadataOverrides.filter { validIDs.contains($0.key) }
        persistFavorites()
        persistRecentPlays()
        persistMetadataOverrides()
    }

    private func applyMetadataOverride(_ track: Track) -> Track {
        metadataOverrides[track.id]?.applying(to: track) ?? track
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favoriteTrackIDs.map(\.uuidString), forKey: PersistenceKey.favorites)
    }

    private func persistRecentPlays() {
        let stored = Dictionary(uniqueKeysWithValues: recentPlayDates.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: PersistenceKey.recentPlays)
        }
    }

    private func persistPlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: PersistenceKey.playlists)
        }
    }

    private nonisolated static var metadataOverridesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("metadata-overrides.json")
    }

    private nonisolated static var artworkOverridesDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ArtworkOverrides", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func persistMetadataOverrides() {
        var stored: [String: TrackMetadataOverride] = [:]
        for (id, var override) in metadataOverrides {
            if let artworkData = override.artworkData {
                let fileName = "track-\(id.uuidString).jpg"
                try? artworkData.write(to: Self.artworkOverridesDirectoryURL.appendingPathComponent(fileName), options: .atomic)
                override.artworkData = nil
                override.artworkFileName = fileName
            }
            stored[id.uuidString] = override
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: Self.metadataOverridesURL, options: .atomic)
    }

    private static func loadMetadataOverrides() -> [UUID: TrackMetadataOverride] {
        guard let data = try? Data(contentsOf: metadataOverridesURL),
              let stored = try? JSONDecoder().decode([String: TrackMetadataOverride].self, from: data) else { return [:] }
        var result: [UUID: TrackMetadataOverride] = [:]
        for (key, value) in stored {
            guard let id = UUID(uuidString: key) else { continue }
            var restored = value
            if let fileName = value.artworkFileName {
                restored.artworkData = try? Data(contentsOf: artworkOverridesDirectoryURL.appendingPathComponent(fileName))
            }
            result[id] = restored
        }
        return result
    }

    private nonisolated static var artistMetadataOverridesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("artist-metadata-overrides.json")
    }

    private func persistArtistMetadataOverrides() {
        let snapshot = artistMetadataOverrides
        Task.detached(priority: .utility) {
            var stored = snapshot
            for (key, var override) in snapshot {
                guard let artworkData = override.artworkData else { continue }
                let fileName = "artist-\(Self.stableArtworkFileName(for: key)).jpg"
                try? artworkData.write(to: Self.artworkOverridesDirectoryURL.appendingPathComponent(fileName), options: .atomic)
                override.artworkData = nil
                override.artworkFileName = fileName
                stored[key] = override
            }
            guard let data = try? JSONEncoder().encode(stored) else { return }
            try? data.write(to: Self.artistMetadataOverridesURL, options: .atomic)
        }
    }

    private static func loadArtistMetadataOverrides() -> [String: ArtistMetadataOverride] {
        guard let data = try? Data(contentsOf: artistMetadataOverridesURL),
              let stored = try? JSONDecoder().decode([String: ArtistMetadataOverride].self, from: data) else { return [:] }
        return stored.mapValues { value in
            var restored = value
            if let fileName = value.artworkFileName {
                restored.artworkData = try? Data(contentsOf: artworkOverridesDirectoryURL.appendingPathComponent(fileName))
            }
            return restored
        }
    }

    private nonisolated static func stableArtworkFileName(for value: String) -> String {
        value.utf8.map { String(format: "%02x", $0) }.joined()
    }

    private func persistIgnoredLocalPaths() {
        UserDefaults.standard.set(Array(ignoredLocalPaths).sorted(), forKey: PersistenceKey.ignoredLocalPaths)
    }

    private static func loadIgnoredLocalPaths() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: PersistenceKey.ignoredLocalPaths) ?? [])
    }

    private static func loadFavoriteIDs() -> Set<UUID> {
        let values = UserDefaults.standard.stringArray(forKey: PersistenceKey.favorites) ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    private static func loadRecentPlayDates() -> [UUID: Date] {
        guard let data = UserDefaults.standard.data(forKey: PersistenceKey.recentPlays),
              let stored = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        var result: [UUID: Date] = [:]
        for (key, value) in stored {
            guard let id = UUID(uuidString: key) else { continue }
            result[id] = Date(timeIntervalSince1970: value)
        }
        return result
    }

    private static func loadPlaylists() -> [UserPlaylist] {
        guard let data = UserDefaults.standard.data(forKey: PersistenceKey.playlists),
              let decoded = try? JSONDecoder().decode([UserPlaylist].self, from: data) else { return [] }
        return decoded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static let demoTracks: [Track] = [
        Track(title: "Glass Horizon", artist: "Northstar", album: "Night Signals", trackNumber: 1, releaseYear: 2024, duration: 254),
        Track(title: "Between Stations", artist: "Northstar", album: "Night Signals", trackNumber: 2, releaseYear: 2024, duration: 221),
        Track(title: "Afterimage", artist: "Northstar", album: "Night Signals", trackNumber: 3, releaseYear: 2024, duration: 289),
        Track(title: "Slow Current", artist: "Northstar", album: "Tidal Memory", trackNumber: 1, releaseYear: 2021, duration: 312),
        Track(title: "Low Light", artist: "Violet Static", album: "Soft Machines", trackNumber: 1, releaseYear: 2023, duration: 198),
        Track(title: "Signal Bloom", artist: "Violet Static", album: "Soft Machines", trackNumber: 2, releaseYear: 2023, duration: 247),
        Track(title: "Open Circuit", artist: "Violet Static", album: "Soft Machines", trackNumber: 3, releaseYear: 2023, duration: 230)
    ]
}
