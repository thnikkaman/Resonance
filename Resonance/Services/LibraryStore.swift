import Foundation
import UniformTypeIdentifiers

private struct LibraryDocumentInventory: Sendable {
    let urls: [URL]
    let modificationDates: [String: Date]
    let sharedFolderTrackCount: Int
}

@MainActor
final class LibraryStore: ObservableObject {
    static let sharedMusicFolderName = "Resonance Music"

    @Published private(set) var tracks: [Track] = []
    @Published var isScanning = false
    @Published var searchText = ""
    @Published var grouping: LibraryGrouping = .artists
    @Published var sortDirection: SortDirection = .ascending
    @Published private(set) var lastSharedFolderScan: Date?
    @Published private(set) var sharedFolderTrackCount = 0
    @Published private(set) var sharedFolderIsReady = false
    @Published private(set) var scanStatus = "Waiting for first scan"
    @Published private(set) var favoriteTrackIDs: Set<UUID> = []
    @Published private(set) var recentPlayDates: [UUID: Date] = [:]
    @Published private(set) var playlists: [UserPlaylist] = []
    @Published private(set) var metadataOverrides: [UUID: TrackMetadataOverride] = [:]
    @Published private(set) var artistMetadataOverrides: [String: ArtistMetadataOverride] = [:]

    private let database = LibraryDatabase()
    private let reader = MetadataReader()
    private var ignoredLocalPaths: Set<String> = []
    private var knownModificationDates: [String: Date] = [:]
    private var didBootstrap = false
    private var lastActiveRefresh: Date?

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
        let base = searchText.isEmpty ? tracks : tracks.filter {
            [$0.title, $0.artist, $0.albumArtist, $0.album].contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        return base.sorted {
            let result = $0.title.localizedStandardCompare($1.title) == .orderedAscending
            return sortDirection == .ascending ? result : !result
        }
    }

    var artists: [Artist] { makeArtists(useAlbumArtist: false) }
    var albumArtists: [Artist] { makeArtists(useAlbumArtist: true) }
    var albums: [Album] {
        let allAlbums = makeAlbums(from: tracks)
        guard !searchText.isEmpty else { return allAlbums }
        return allAlbums.filter { album in
            album.title.localizedCaseInsensitiveContains(searchText) ||
            album.artist.localizedCaseInsensitiveContains(searchText) ||
            album.tracks.contains { track in
                [track.title, track.artist, track.albumArtist, track.album]
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
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
        ensureSharedMusicFolder()

        let stored = await database.loadAll().filter { track in
            guard let url = track.fileURL else { return true }
            return !ignoredLocalPaths.contains(Self.normalizedPathForInventory(url))
        }
        tracks = stored.map(applyMetadataOverride)
        knownModificationDates = await Task.detached(priority: .utility) {
            Self.modificationDates(for: stored)
        }.value
        await scanDocuments(forceMetadataRefresh: false)

        if tracks.isEmpty {
            tracks = Self.demoTracks
            scanStatus = "Shared folder ready — no transferred music found"
        }
    }

    func refreshForActiveState() async {
        if didBootstrap {
            let now = Date()
            if let lastActiveRefresh, now.timeIntervalSince(lastActiveRefresh) < 30 {
                return
            }
            lastActiveRefresh = now
            await scanDocuments(forceMetadataRefresh: false)
        } else {
            await bootstrap()
        }
    }

    func scanSharedMusicFolder(forceMetadataRefresh: Bool = true) async {
        ensureSharedMusicFolder()
        await scanDocuments(forceMetadataRefresh: forceMetadataRefresh)
    }

    func importURLs(_ urls: [URL]) async {
        ensureSharedMusicFolder()
        isScanning = true
        scanStatus = "Copying selected music…"
        defer { isScanning = false }

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
                } catch {
                    continue
                }
            }
        }

        isScanning = false
        persistIgnoredLocalPaths()
        await scanDocuments(forceMetadataRefresh: false)
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
        if let artworkData = track.artworkData { return artworkData }
        return tracks.first {
            $0.artworkData != nil &&
            $0.album.localizedCaseInsensitiveCompare(track.album) == .orderedSame &&
            ($0.albumArtist.localizedCaseInsensitiveCompare(track.albumArtist) == .orderedSame ||
             $0.artist.localizedCaseInsensitiveCompare(track.artist) == .orderedSame)
        }?.artworkData
    }

    func artworkIsEmbedded(for track: Track) -> Bool {
        if track.artworkData != nil { return track.artworkIsEmbedded }
        return tracks.first {
            $0.artworkData != nil &&
            $0.album.localizedCaseInsensitiveCompare(track.album) == .orderedSame &&
            ($0.albumArtist.localizedCaseInsensitiveCompare(track.albumArtist) == .orderedSame ||
             $0.artist.localizedCaseInsensitiveCompare(track.artist) == .orderedSame)
        }?.artworkIsEmbedded ?? true
    }

    func hasMetadataOverride(_ track: Track) -> Bool {
        metadataOverrides[track.id] != nil
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
        do {
            try await writeTags(to: url, values: values, artworkData: artworkData, replaceArtwork: replaceArtwork)
        } catch {
            return error.localizedDescription
        }

        metadataOverrides.removeValue(forKey: trackID)
        persistMetadataOverrides()
        await scanDocuments(forceMetadataRefresh: true)
        return nil
    }

    func refreshedArtist(_ artist: Artist) -> Artist {
        let ids = Set(artist.albums.flatMap(\.tracks).map(\.id))
        let currentTracks = tracks.filter { ids.contains($0.id) }
        guard let first = currentTracks.first else { return artist }
        let currentName = artist.usesAlbumArtist ? first.albumArtist : first.artist
        return makeArtist(name: currentName, tracks: currentTracks, useAlbumArtist: artist.usesAlbumArtist)
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
        var writableIDs = Set<UUID>()
        var failures: [String] = []

        for track in tracks where ids.contains(track.id) {
            guard let url = track.fileURL, !track.isRemote else { continue }
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
            do {
                try await writeTags(to: url, values: values, artworkData: artworkData, replaceArtwork: replaceArtwork || clearArtworkOverride)
                writableIDs.insert(track.id)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        let oldKey = artistOverrideKey(name: oldName, useAlbumArtist: artist.usesAlbumArtist)
        let newKey = artistOverrideKey(name: cleanedName, useAlbumArtist: artist.usesAlbumArtist)
        // Artist edits are written into every writable local track. Remove
        // any older Resonance-only artist artwork/name override so the view
        // reflects the actual file tags after the rescan.
        artistMetadataOverrides.removeValue(forKey: oldKey)
        artistMetadataOverrides.removeValue(forKey: newKey)

        for id in writableIDs { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        persistArtistMetadataOverrides()
        await scanDocuments(forceMetadataRefresh: true)
        return failures.isEmpty ? nil : failures.first
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
        var writableIDs = Set<UUID>()
        var failures: [String] = []
        for track in tracks where ids.contains(track.id) {
            guard let url = track.fileURL, !track.isRemote else { continue }
            let values = MetadataTagValues(
                title: track.title,
                artist: track.artist,
                albumArtist: albumArtist.trimmingCharacters(in: .whitespacesAndNewlines),
                album: album.trimmingCharacters(in: .whitespacesAndNewlines),
                trackNumber: track.trackNumber,
                discNumber: track.discNumber,
                releaseYear: max(0, releaseYear)
            )
            do {
                try await writeTags(to: url, values: values, artworkData: artworkData, replaceArtwork: replaceArtwork)
                writableIDs.insert(track.id)
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        for id in writableIDs { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        await scanDocuments(forceMetadataRefresh: true)
        return failures.isEmpty ? nil : failures.first
    }

    private func writeTags(
        to url: URL,
        values: MetadataTagValues,
        artworkData: Data?,
        replaceArtwork: Bool
    ) async throws {
        try await Task.detached(priority: .utility) {
            try MetadataTagWriter.write(
                to: url,
                values: values,
                artworkData: artworkData,
                replaceArtwork: replaceArtwork
            )
        }.value
    }

    func resetMetadataOverrides(for trackIDs: [UUID]) async {
        let ids = Set(trackIDs)
        for id in ids { metadataOverrides.removeValue(forKey: id) }
        persistMetadataOverrides()
        await scanDocuments(forceMetadataRefresh: true)
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
        for track in removed {
            guard let url = track.fileURL else { continue }
            let path = normalizedPath(url)
            if deletingFiles {
                ignoredLocalPaths.remove(path)
                try? FileManager.default.removeItem(at: url)
            } else {
                ignoredLocalPaths.insert(path)
            }
        }
        persistIgnoredLocalPaths()
        await database.replaceAll(with: tracks.filter { $0.fileURL != nil })
        await scanDocuments(forceMetadataRefresh: false)
    }

    func resetDemoLibrary() async {
        tracks = Self.demoTracks
        await database.replaceAll(with: [])
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
        isScanning = !hadExistingContent
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
            artworkData: parsed.artworkData ?? existing.artworkData,
            artworkIsEmbedded: parsed.artworkData != nil ? parsed.artworkIsEmbedded : existing.artworkIsEmbedded,
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

    private func deduplicate(_ input: [Track]) -> [Track] {
        Array(
            Dictionary(
                grouping: input,
                by: { $0.fileURL.map(normalizedPath) ?? $0.id.uuidString }
            ).compactMap(\.value.last)
        )
    }

    private func makeArtists(useAlbumArtist: Bool) -> [Artist] {
        let groups = Dictionary(grouping: tracks) { useAlbumArtist ? $0.albumArtist : $0.artist }
        var mapped = groups.map { name, values in
            makeArtist(name: name, tracks: values, useAlbumArtist: useAlbumArtist)
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

    private func makeArtist(name: String, tracks: [Track], useAlbumArtist: Bool) -> Artist {
        let key = artistOverrideKey(name: name, useAlbumArtist: useAlbumArtist)
        let artworkOverride = artistMetadataOverrides[key]
        let hasTrackOverride = tracks.contains { track in
            guard let override = metadataOverrides[track.id] else { return false }
            return useAlbumArtist ? override.albumArtist != nil : override.artist != nil
        }
        return Artist(
            id: key,
            name: name,
            albums: makeAlbums(from: tracks),
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

    private func makeAlbums(from tracks: [Track]) -> [Album] {
        Dictionary(grouping: tracks, by: { "\($0.albumArtist)|\($0.album)" }).map { key, values in
            let sorted = values.sorted { ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title) }
            return Album(
                id: key,
                title: sorted.first?.album ?? "Unknown Album",
                artist: sorted.first?.albumArtist ?? "Unknown Artist",
                tracks: sorted
            )
        }.sorted {
            sortDirection == .ascending
                ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                : $0.title.localizedStandardCompare($1.title) == .orderedDescending
        }
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

    private static var metadataOverridesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("metadata-overrides.json")
    }

    private func persistMetadataOverrides() {
        let stored = Dictionary(uniqueKeysWithValues: metadataOverrides.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: Self.metadataOverridesURL, options: .atomic)
    }

    private static func loadMetadataOverrides() -> [UUID: TrackMetadataOverride] {
        guard let data = try? Data(contentsOf: metadataOverridesURL),
              let stored = try? JSONDecoder().decode([String: TrackMetadataOverride].self, from: data) else { return [:] }
        var result: [UUID: TrackMetadataOverride] = [:]
        for (key, value) in stored {
            guard let id = UUID(uuidString: key) else { continue }
            result[id] = value
        }
        return result
    }

    private static var artistMetadataOverridesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("artist-metadata-overrides.json")
    }

    private func persistArtistMetadataOverrides() {
        guard let data = try? JSONEncoder().encode(artistMetadataOverrides) else { return }
        try? data.write(to: Self.artistMetadataOverridesURL, options: .atomic)
    }

    private static func loadArtistMetadataOverrides() -> [String: ArtistMetadataOverride] {
        guard let data = try? Data(contentsOf: artistMetadataOverridesURL),
              let stored = try? JSONDecoder().decode([String: ArtistMetadataOverride].self, from: data) else { return [:] }
        return stored
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
