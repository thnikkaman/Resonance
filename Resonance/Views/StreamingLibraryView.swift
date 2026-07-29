import SwiftUI
import UIKit
import ImageIO

private struct RemoteTrackSwipeActions: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    let track: RemoteTrackItem

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    Task { await remote.playNext([track], using: player) }
                } label: {
                    Label("Play Next", systemImage: "text.insert")
                }
                .tint(.indigo)

                Button {
                    Task { await remote.addToQueue([track], using: player) }
                } label: {
                    Label("Add to Queue", systemImage: "text.append")
                }
                .tint(settings.accentColor)
            }
    }
}

private struct RemoteTrackDownloadSwipeAction: ViewModifier {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    let track: RemoteTrackItem

    func body(content: Content) -> some View {
        content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                downloads.requestDownload([track], into: library)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .tint(.green)
        }
    }
}

private extension View {
    func remoteTrackSwipeActions(_ track: RemoteTrackItem) -> some View {
        modifier(RemoteTrackSwipeActions(track: track))
    }

    func remoteTrackDownloadSwipeAction(_ track: RemoteTrackItem) -> some View {
        modifier(RemoteTrackDownloadSwipeAction(track: track))
    }

    func remoteDetailBackSwipe(action: @escaping () -> Void) -> some View {
        highPriorityGesture(
            DragGesture(minimumDistance: 45, coordinateSpace: .local)
                .onEnded { value in
                    guard value.translation.height > 70,
                          abs(value.translation.height) > abs(value.translation.width)
                    else { return }
                    action()
                }
        )
    }
}

struct StreamingLibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @EnvironmentObject private var library: LibraryStore
    @State private var showingOptions = false
    @State private var browseReady = false
    @State private var downloadSelectionMode = false
    @State private var selectedArtistIDs: Set<String> = []
    @State private var selectedAlbumIDs: Set<String> = []
    @State private var artistBrowseSnapshot: [RemoteArtist] = []
    @State private var albumBrowseSnapshot: [RemoteAlbum] = []
    let openLibrary: () -> Void
    let openSettings: () -> Void

    private var selectedArtistCount: Int { selectedArtistIDs.count }
    private var selectedAlbumCount: Int { selectedAlbumIDs.count }

    private var browseSnapshotKey: String {
        [
            String(remote.browseRevisionForViews),
            remote.grouping.rawValue,
            remote.sortDirection.rawValue,
            String(settings.groupCompilationArtists)
        ].joined(separator: "|")
    }

    private var visibleArtists: [RemoteArtist] {
        artistBrowseSnapshot.isEmpty
            ? (remote.grouping == .albumArtists
                ? remote.albumArtists(groupCompilationArtists: settings.groupCompilationArtists)
                : remote.artists(groupCompilationArtists: settings.groupCompilationArtists))
            : artistBrowseSnapshot
    }

    private var visibleAlbums: [RemoteAlbum] {
        albumBrowseSnapshot.isEmpty ? remote.albums : albumBrowseSnapshot
    }

    private var selectedArtistTracks: [RemoteTrackItem] {
        visibleArtists
            .filter { selectedArtistIDs.contains($0.id) }
            .flatMap(\.tracks)
    }

    private var selectedAlbumTracks: [RemoteTrackItem] {
        visibleAlbums
            .filter { selectedAlbumIDs.contains($0.id) }
            .flatMap(\.tracks)
    }

    private func clearDownloadSelection() {
        downloadSelectionMode = false
        selectedArtistIDs.removeAll()
        selectedAlbumIDs.removeAll()
    }

    var body: some View {
        Group {
            if settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView {
                    Label("No Remote Server", systemImage: "externaldrive.badge.wifi")
                } description: {
                    Text("Add a server URL or Tailscale host and choose the correct backend in Settings.")
                } actions: {
                    Button("Open Streaming Settings", action: openSettings)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 0) {
                    RemoteDownloadOverlay()
                        .padding(.top, 84)
                    if remote.hasConnectionIssue {
                        RemoteServerHeader()
                    }
                    if browseReady {
                        Group {
                            switch remote.grouping {
                            case .artists:
                                RemoteArtistCollectionView(
                                    artists: visibleArtists,
                                    sortDirection: remote.sortDirection,
                                    selectionMode: $downloadSelectionMode,
                                    selectedIDs: $selectedArtistIDs,
                                    onBeginSelection: { artistID in
                                        selectedAlbumIDs.removeAll()
                                        selectedArtistIDs = [artistID]
                                        downloadSelectionMode = true
                                    }
                                )
                            case .albumArtists:
                                RemoteArtistCollectionView(
                                    artists: visibleArtists,
                                    sortDirection: remote.sortDirection,
                                    selectionMode: $downloadSelectionMode,
                                    selectedIDs: $selectedArtistIDs,
                                    onBeginSelection: { artistID in
                                        selectedAlbumIDs.removeAll()
                                        selectedArtistIDs = [artistID]
                                        downloadSelectionMode = true
                                    }
                                )
                            case .albums:
                                RemoteAlbumCollectionView(
                                    albums: visibleAlbums,
                                    sortDirection: remote.sortDirection,
                                    selectionMode: $downloadSelectionMode,
                                    selectedIDs: $selectedAlbumIDs,
                                    onBeginSelection: { albumID in
                                        selectedArtistIDs.removeAll()
                                        selectedAlbumIDs = [albumID]
                                        downloadSelectionMode = true
                                    }
                                )
                            case .songs:
                                RemoteTrackCollectionView(tracks: remote.filteredTracks)
                            case .favorites:
                                RemoteTrackCollectionView(tracks: remote.favoriteTracks)
                            case .recentlyAdded:
                                RemoteTrackCollectionView(tracks: remote.recentlyAddedTracks)
                            case .recentlyPlayed:
                                RemoteTrackCollectionView(tracks: remote.recentlyPlayedTracks)
                            }
                        }
                        .overlay {
                            if !remote.isLoading && remote.filteredTracks.isEmpty {
                                ContentUnavailableView(
                                    "No Remote Music",
                                    systemImage: "music.note.list",
                                    description: Text("Refresh the remote library, verify the selected backend, or change the current search.")
                                )
                            }
                        }
                        .refreshable { await remote.refresh(using: settings) }
                    } else {
                        ProgressView("Preparing Streaming…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Streaming Library")
        .navigationBarTitleDisplayMode(.large)
        .background {
            Color.clear
        }
        .onChange(of: selectedArtistIDs) { _, ids in
            if ids.isEmpty && selectedAlbumIDs.isEmpty { downloadSelectionMode = false }
        }
        .onChange(of: selectedAlbumIDs) { _, ids in
            if ids.isEmpty && selectedArtistIDs.isEmpty { downloadSelectionMode = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Open local library",
                    systemImage: "chevron.left",
                    action: openLibrary
                )

                StreamingDownloadActionsMenu(
                    artistTracks: selectedArtistTracks,
                    albumTracks: selectedAlbumTracks,
                    artistCount: selectedArtistCount,
                    albumCount: selectedAlbumCount,
                    selectionMode: downloadSelectionMode,
                    onClearSelection: clearDownloadSelection,
                    onShowBrowseOptions: { showingOptions = true }
                )

                Menu {
                    NavigationLink {
                        RemotePlaylistCollectionView()
                    } label: {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                } label: {
                    ResonanceToolbarIconLabel(systemImage: "music.note.list")
                }
                .disabled(settings.streamBackend != .subsonic)
                .help("Open playlists")
                .accessibilityLabel("Open playlists")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Refresh streaming library",
                    systemImage: "arrow.clockwise"
                ) {
                    Task { await remote.refresh(using: settings) }
                }
                .disabled(remote.isLoading || settings.streamHost.isEmpty)
            }
        }
        .sheet(isPresented: $showingOptions) {
            RemoteLibraryOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .task {
            await remote.activateCachedCatalogAndCheckForChanges(using: settings)
        }
        .task(id: browseSnapshotKey) {
            switch remote.grouping {
            case .artists:
                artistBrowseSnapshot = remote.artists(groupCompilationArtists: settings.groupCompilationArtists)
            case .albumArtists:
                artistBrowseSnapshot = remote.albumArtists(groupCompilationArtists: settings.groupCompilationArtists)
            case .albums:
                albumBrowseSnapshot = remote.albums
            default:
                artistBrowseSnapshot = []
                albumBrowseSnapshot = []
            }
        }
        .task(id: settings.streamHost) {
            browseReady = false
            await Task.yield()
            guard !Task.isCancelled else { return }
            browseReady = true
        }
        .onAppear {
            ResonanceDiagnostics.shared.recordDeferred(
                "streaming.view.appeared",
                details: [
                    "grouping": remote.grouping.rawValue,
                    "connectionIssue": String(remote.hasConnectionIssue)
                ]
            )
        }
        .overlay(alignment: .leading) {
            // Keep back navigation confined to the left edge so ordinary
            // vertical drags over artists remain owned by the scroll view.
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            if value.translation.width > 70,
                               abs(value.translation.width) > abs(value.translation.height) {
                                openLibrary()
                            }
                        }
                )
        }
    }

}

private struct StreamingDownloadActionsMenu: View {
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @EnvironmentObject private var library: LibraryStore

    let artistTracks: [RemoteTrackItem]
    let albumTracks: [RemoteTrackItem]
    let artistCount: Int
    let albumCount: Int
    let selectionMode: Bool
    let onClearSelection: () -> Void
    let onShowBrowseOptions: () -> Void

    private var hasSelection: Bool { artistCount > 0 || albumCount > 0 }

    var body: some View {
        Menu {
            if artistCount > 0 {
                Button(artistCount == 1 ? "Download Artist" : "Download Artists") {
                    requestDownload(artistTracks)
                }
            }
            if albumCount > 0 {
                Button(albumCount == 1 ? "Download Album" : "Download Albums") {
                    requestDownload(albumTracks)
                }
            }
            if selectionMode {
                Divider()
                Button("Clear Download Selection", action: onClearSelection)
            }
            if hasSelection { Divider() }
            Button("Browse and Sort Options", action: onShowBrowseOptions)
        } label: {
            ResonanceToolbarIconLabel(systemImage: selectionMode ? "checkmark.circle" : "slider.horizontal.3")
        }
        .help(selectionMode ? "Download selection options" : "Streaming library view and sort options")
        .accessibilityLabel(selectionMode ? "Download selection options" : "Streaming library view and sort options")
    }

    private func requestDownload(_ tracks: [RemoteTrackItem]) {
        let uniqueTracks = tracks.reduce(into: [RemoteTrackItem]()) { result, track in
            if !result.contains(where: { $0.id == track.id }) { result.append(track) }
        }
        guard !uniqueTracks.isEmpty else { return }
        downloads.requestDownload(uniqueTracks, into: library)
        onClearSelection()
    }
}

struct RemoteDownloadOverlay: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ZStack(alignment: .top) {
            if downloads.pendingReplacementCount > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Files Already Exist")
                        .font(.headline)
                    Text(downloads.pendingReplacementDescription)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Keep Existing") {
                            downloads.keepExistingAndDownloadNew()
                        }
                        .buttonStyle(.bordered)
                        Spacer(minLength: 8)
                        Button("Replace Existing", role: .destructive) {
                            downloads.confirmReplacement()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Cancel", role: .cancel) {
                        downloads.cancelPendingReplacement()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.caption.weight(.semibold))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(settings.themeSurfaceGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .padding(.horizontal, 12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("File replacement options")
            } else if downloads.isDownloading {
                RemoteDownloadBanner(
                    title: downloads.currentTitle,
                    completed: downloads.completedCount,
                    total: downloads.totalCount,
                    completedBytes: downloads.currentCompletedBytes,
                    totalBytes: downloads.currentTotalBytes,
                    queue: downloads.downloadQueue,
                    cancel: downloads.cancel,
                    cancelTrack: downloads.cancelDownload,
                    requeueTrack: downloads.requeueDownload
                )
            } else if downloads.hasPersistedQueue {
                HStack(spacing: 10) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                    Text("A download is ready to resume")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Resume") {
                        downloads.resumePersistedDownloads(from: remote.tracks, into: library)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(settings.themeSurfaceGradient)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("A download is ready to resume")
            } else {
                EmptyView()
            }
        }
    }
}

private struct RemoteDownloadBanner: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let completed: Int
    let total: Int
    let completedBytes: Int64
    let totalBytes: Int64
    let queue: [RemoteDownloadProgress]
    let cancel: () -> Void
    let cancelTrack: (UUID) -> Void
    let requeueTrack: (UUID) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if totalBytes > 0 {
                        ProgressView(
                            value: Double(completedBytes),
                            total: Double(totalBytes)
                        )
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloading \(min(completed + 1, total)) of \(total)")
                        .font(.caption.weight(.semibold))
                    Text(title)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    if totalBytes > 0 {
                        Text("\(ByteCountFormatter.string(fromByteCount: completedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Hide download queue" : "Show download queue")
                Button(action: cancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel all downloads")
            }
            if isExpanded {
                HStack {
                    Text("Download Queue")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = false
                        }
                    } label: {
                        Label("Collapse", systemImage: "chevron.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Collapse download queue")
                }
                .padding(.top, 2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(queue) { item in
                            RemoteDownloadQueueRow(item: item, cancel: cancelTrack, requeue: requeueTrack)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(settings.themeSurfaceGradient)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Download queue, \(completed) of \(total) completed")
    }
}

private struct RemoteDownloadQueueRow: View {
    let item: RemoteDownloadProgress
    let cancel: (UUID) -> Void
    let requeue: (UUID) -> Void

    private var statusText: String {
        switch item.state {
        case .queued: "Queued"
        case .downloading: "Downloading"
        case .completed: "Completed"
        case .skipped: "Kept existing"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    private var iconName: String {
        switch item.state {
        case .queued: "clock"
        case .downloading: "arrow.down.circle"
        case .completed, .skipped: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "minus.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(item.state == .failed ? .orange : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.state == .queued || item.state == .downloading {
                Button {
                    cancel(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel \(item.title)")
            } else if item.state == .cancelled {
                Button {
                    requeue(item.id)
                } label: {
                    Label("Requeue", systemImage: "arrow.clockwise.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Requeue \(item.title)")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(statusText)")
    }
}

private struct RemoteServerHeader: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streaming connection issue")
                        .font(.headline)
                    Text(remote.serverName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settings.accentColor)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    Task { await remote.refresh(using: settings) }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(remote.isLoading)
                .accessibilityLabel("Reconnect to (remote.serverName)")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(settings.streamBackend.shortName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(settings.accentColor)
                Text(remote.connectionStatus)
                    .font(.caption)
                    .foregroundStyle(settings.themeSecondaryColor)
                    .lineLimit(2)
                Text(remote.catalogSyncStatus)
                    .font(.caption2)
                    .foregroundStyle(settings.themeSecondaryColor)
                    .lineLimit(2)
                if let lastRefresh = remote.lastRefresh {
                    Text("Last successful update \(lastRefresh.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(settings.themeSecondaryColor)
                }
            }
            .padding(.top, 4)
        }
        .tint(settings.accentColor)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(settings.themeSurfaceGradient)
        .zIndex(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streaming connection issue")
    }
}

private struct RemoteLibraryOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Browse Streaming Library By") {
                    Picker("Remote grouping", selection: $remote.grouping) {
                        ForEach(RemoteBrowseGrouping.allCases) { grouping in
                            Text(grouping.rawValue).tag(grouping)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Sort Order") {
                    Picker("Sort direction", selection: $remote.sortDirection) {
                        ForEach(SortDirection.allCases) { direction in
                            Label(
                                direction.rawValue,
                                systemImage: direction == .ascending ? "arrow.up" : "arrow.down"
                            )
                            .tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("View Style") {
                    Picker("Streaming view style", selection: $settings.albumLayout) {
                        ForEach(AlbumLayout.allCases) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("View Options") {
                    Toggle(
                        "Group compilation-only artists",
                        isOn: $settings.groupCompilationArtists
                    )
                    Text("In Artists and Album Artists views, tracks from compilation albums appear under a single Various Artists entry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Artwork size", selection: $settings.libraryThumbnailSize) {
                        ForEach(LibraryThumbnailSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    Picker("Text size", selection: $settings.libraryTextSize) {
                        ForEach(LibraryTextSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                }
            }
            .navigationTitle("Streaming Library Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: remote.grouping) { _, grouping in
                ResonanceDiagnostics.shared.recordDeferred(
                    "streaming.option.grouping.changed",
                    details: ["grouping": grouping.rawValue]
                )
            }
            .onChange(of: remote.sortDirection) { _, direction in
                ResonanceDiagnostics.shared.recordDeferred(
                    "streaming.option.sort.changed",
                    details: ["direction": direction.rawValue]
                )
            }
            .onChange(of: settings.groupCompilationArtists) { _, enabled in
                ResonanceDiagnostics.shared.recordDeferred(
                    "streaming.option.compilationGrouping.changed",
                    details: ["enabled": String(enabled)]
                )
            }
            .onChange(of: settings.albumLayout) { _, layout in
                ResonanceDiagnostics.shared.recordDeferred(
                    "streaming.option.layout.changed",
                    details: ["layout": layout.rawValue]
                )
            }
        }
    }
}

private struct RemoteArtistCollectionView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
  @EnvironmentObject private var layeredNavigation: ResonanceLayerNavigation
  let artists: [RemoteArtist]
  let sortDirection: SortDirection
  @Binding var selectionMode: Bool
  @Binding var selectedIDs: Set<String>
  let onBeginSelection: (String) -> Void
  private let artistIDs: [String]
  @State private var sections: [ArtistIndexSection<RemoteArtist>] = []
  @State private var destinationArtist: RemoteArtist?
  @State private var longPressRecognized = false

  init(
    artists: [RemoteArtist],
    sortDirection: SortDirection,
    selectionMode: Binding<Bool>,
    selectedIDs: Binding<Set<String>>,
    onBeginSelection: @escaping (String) -> Void
  ) {
    self.artists = artists
    self.sortDirection = sortDirection
    _selectionMode = selectionMode
    _selectedIDs = selectedIDs
    self.onBeginSelection = onBeginSelection
    self.artistIDs = artists.map(\.id)
  }

  private var sectionInputKey: String {
    "\(sortDirection.rawValue)|\(artistIDs.joined(separator: ","))"
  }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

  private static func makeSections(
    _ artists: [RemoteArtist],
    ascending: Bool
  ) -> [ArtistIndexSection<RemoteArtist>] {
    let uniqueArtists = Dictionary(grouping: artists) { resonanceNormalizedRemoteKey($0.name) }
            .compactMap { _, values in values.first }
        let grouped = Dictionary(grouping: uniqueArtists) { resonanceArtistIndexKey($0.name) }
    let order = resonanceArtistIndexOrder(
      for: Array(grouped.keys),
      ascending: ascending
    )
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
            items: ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    private func toggleSelection(_ artist: RemoteArtist) {
        if selectedIDs.contains(artist.id) {
            selectedIDs.remove(artist.id)
        } else {
            selectedIDs.insert(artist.id)
        }
    }

    @ViewBuilder
    private func artistTile(_ artist: RemoteArtist) -> some View {
        ZStack(alignment: .topTrailing) {
            RemoteArtistTile(artist: artist)
            if selectionMode {
                DownloadSelectionBubble(isSelected: selectedIDs.contains(artist.id))
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private func artistItem(_ artist: RemoteArtist) -> some View {
        Button {
            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
            if longPressRecognized {
                longPressRecognized = false
            } else if selectionMode {
                toggleSelection(artist)
            } else {
                layeredNavigation.remoteArtist = artist
                layeredNavigation.layer = .artist
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                if settings.albumLayout == .grid {
                    artistTile(artist)
                } else {
                    RemoteCollectionRow(
                        title: artist.name,
                        subtitle: "\(artist.albums.count) albums • \(artist.tracks.count) tracks",
                        artwork: RemoteArtworkContext(artist),
                        large: settings.albumLayout == .large,
                    )
                    if selectionMode {
                        DownloadSelectionBubble(isSelected: selectedIDs.contains(artist.id))
                            .padding(.trailing, 8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contentShape(Rectangle())
        .simultaneousGesture(
            // A zero-distance drag also receives the ScrollView's first touch and
            // turns a slow scroll into a selection. LongPressGesture cancels when
            // the finger moves beyond its small hold radius, leaving scrolling to
            // the enclosing ScrollView.
            LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                .onEnded { _ in
                    guard !selectionMode else { return }
                    longPressRecognized = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onBeginSelection(artist.id)
                }
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    Group {
                        if settings.albumLayout == .grid {
                            ResonanceAlphabetGrid(
                                sections: sections,
                                columns: columns,
                                sectionIDPrefix: "remote-artist-section",
                                sectionLabelColor: settings.textAccentColor
                            ) { artist in
                                artistItem(artist)
                            }
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(sections, id: \.key) { section in
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(section.key)
                                            .font(.headline)
                                            .foregroundStyle(settings.textAccentColor)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 7)

                                        ForEach(section.items) { artist in
                                            artistItem(artist)
                                                .padding(.vertical, settings.albumLayout == .compact ? 3 : 8)
                                        }
                                    }
                                    .id("remote-artist-section-\(section.key)")
                                }
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 36)
                    .padding(.top, 84)
                }
                .resonanceBrowseBottomClearance()

                if sections.count > 1 {
                    VerticalArtistIndex(
                        keys: sections.map(\.key),
                        diagnosticSurface: "streaming-artists"
                    ) { key in
                        ResonanceDiagnostics.shared.recordDeferred(
                            "alphabet.scrollTo",
                            details: [
                                "surface": "streaming-artists",
                                "key": key,
                                "sectionCount": String(sections.count)
                            ]
                        )
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("remote-artist-section-\(key)", anchor: .top)
                        }
                    }
                    .zIndex(2)
                    .padding(.trailing, 1)
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.hidden)
            .task(id: sectionInputKey) {
                sections = Self.makeSections(artists, ascending: sortDirection == .ascending)
                }
            }
            .fullScreenCover(item: $destinationArtist) { artist in
                NavigationStack {
                    RemoteArtistDetailView(artist: artist)
                }
            }
        }
    }

private struct DownloadSelectionBubble: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(2)
            .background(.ultraThinMaterial, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct RemoteArtistTile: View {
    @EnvironmentObject private var settings: AppSettings
    let artist: RemoteArtist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteArtwork(
                context: RemoteArtworkContext(artist),
                size: settings.libraryThumbnailSize.gridArtworkPoints,
            )
            .frame(maxWidth: .infinity)
            Text(artist.name)
                .font(settings.libraryTextSize.font.weight(.semibold))
                .lineLimit(1)
            Text("\(artist.albums.count) album\(artist.albums.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct RemoteAlbumCollectionView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
  @EnvironmentObject private var layeredNavigation: ResonanceLayerNavigation
  let albums: [RemoteAlbum]
  let sortDirection: SortDirection
  @Binding var selectionMode: Bool
  @Binding var selectedIDs: Set<String>
  let onBeginSelection: (String) -> Void
  private let albumIDs: [String]
  @State private var sections: [ArtistIndexSection<RemoteAlbum>] = []
  @State private var destinationAlbum: RemoteAlbum?
  @State private var longPressRecognized = false

  init(
    albums: [RemoteAlbum],
    sortDirection: SortDirection,
    selectionMode: Binding<Bool>,
    selectedIDs: Binding<Set<String>>,
    onBeginSelection: @escaping (String) -> Void
  ) {
    self.albums = albums
    self.sortDirection = sortDirection
    _selectionMode = selectionMode
    _selectedIDs = selectedIDs
    self.onBeginSelection = onBeginSelection
    self.albumIDs = albums.map(\.id)
  }

  private var sectionInputKey: String {
    "\(sortDirection.rawValue)|\(albumIDs.joined(separator: ","))"
  }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

  private static func makeSections(
    _ albums: [RemoteAlbum],
    ascending: Bool
  ) -> [ArtistIndexSection<RemoteAlbum>] {
    let grouped = Dictionary(grouping: albums) { resonanceArtistIndexKey($0.title) }
    let order = resonanceArtistIndexOrder(
        for: Array(grouped.keys),
            ascending: ascending
        )
        return order.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            let sorted = values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
              items: ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    private func toggleSelection(_ album: RemoteAlbum) {
        if selectedIDs.contains(album.id) {
            selectedIDs.remove(album.id)
        } else {
            selectedIDs.insert(album.id)
        }
    }

    @ViewBuilder
    private func albumTile(_ album: RemoteAlbum) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteArtwork(
                    context: RemoteArtworkContext(album),
                    size: settings.libraryThumbnailSize.gridArtworkPoints,
                )
                Text(album.title)
                    .font(settings.libraryTextSize.font.weight(.semibold))
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if selectionMode {
                DownloadSelectionBubble(isSelected: selectedIDs.contains(album.id))
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private func albumItem(_ album: RemoteAlbum) -> some View {
        Button {
            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
            if longPressRecognized {
                longPressRecognized = false
            } else if selectionMode {
                toggleSelection(album)
            } else {
                layeredNavigation.remoteAlbum = album
                layeredNavigation.layer = .album
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                if settings.albumLayout == .grid {
                    albumTile(album)
                } else {
                    RemoteCollectionRow(
                        title: album.title,
                        subtitle: album.releaseYear > 0 ? "\(album.artist) • \(album.releaseYear)" : album.artist,
                        artwork: RemoteArtworkContext(album),
                        large: settings.albumLayout == .large,
                    )
                    if selectionMode {
                        DownloadSelectionBubble(isSelected: selectedIDs.contains(album.id))
                            .padding(.trailing, 8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                .onEnded { _ in
                    guard !selectionMode else { return }
                    longPressRecognized = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onBeginSelection(album.id)
                }
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    Group {
                        if settings.albumLayout == .grid {
                            ResonanceAlphabetGrid(
                                sections: sections,
                                columns: columns,
                                sectionIDPrefix: "remote-album-section",
                                sectionLabelColor: settings.textAccentColor
                            ) { album in
                                albumItem(album)
                            }
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(sections, id: \.key) { section in
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(section.key)
                                            .font(.headline)
                                            .foregroundStyle(settings.textAccentColor)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 7)

                                        ForEach(section.items) { album in
                                            albumItem(album)
                                                .padding(.vertical, settings.albumLayout == .compact ? 2 : 8)
                                            Divider()
                                        }
                                    }
                                    .id("remote-album-section-\(section.key)")
                                }
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 36)
                    .padding(.vertical)
                }
                .resonanceBrowseBottomClearance()

                if sections.count > 1 {
                    VerticalArtistIndex(
                        keys: sections.map(\.key),
                        diagnosticSurface: "streaming-albums"
                    ) { key in
                        ResonanceDiagnostics.shared.recordDeferred(
                            "alphabet.scrollTo",
                            details: [
                                "surface": "streaming-albums",
                                "key": key,
                                "sectionCount": String(sections.count)
                            ]
                        )
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("remote-album-section-\(key)", anchor: .top)
                        }
                    }
                    .zIndex(2)
                    .padding(.trailing, 1)
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.hidden)
            .background {
                ResonanceThemeBackdrop()
            }
            .task(id: sectionInputKey) {
                sections = Self.makeSections(albums, ascending: sortDirection == .ascending)
                }
            }
            .fullScreenCover(item: $destinationAlbum) { album in
                NavigationStack {
                    RemoteAlbumDetailView(album: album)
                }
            }
        }
    }

private struct RemoteTrackCollectionView: View {
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @State private var playlistItems: [RemoteTrackItem] = []
    @State private var showingPlaylistPicker = false
    let tracks: [RemoteTrackItem]

    var body: some View {
        List {
            ForEach(tracks) { track in
                Button {
                    Task { await remote.play(track, in: tracks, using: player) }
                } label: {
                    RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        Task { await remote.playNext([track], using: player) }
                    } label: {
                        Label("Play Next", systemImage: "text.insert")
                    }
                    .tint(settings.accentColor)

                    Button {
                        Task { await remote.addToQueue([track], using: player) }
                    } label: {
                        Label("Add to Queue", systemImage: "text.append")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        downloads.requestDownload([track], into: library)
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .tint(.green)
                }
                .contextMenu {
                    Button {
                        Task { await remote.playNext([track], using: player) }
                    } label: {
                        Label("Play Next", systemImage: "text.insert")
                    }
                    Button {
                        Task { await remote.addToQueue([track], using: player) }
                    } label: {
                        Label("Add to End of Queue", systemImage: "text.append")
                    }
                    Button {
                        downloads.requestDownload([track], into: library)
                    } label: {
                        Label("Download Track", systemImage: "arrow.down.circle")
                    }
                    if settings.streamBackend == .subsonic {
                        Button {
                            Task { await remote.toggleFavorite(track, using: settings) }
                        } label: {
                            Label(
                                track.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: track.isFavorite ? "heart.slash" : "heart"
                            )
                        }
                        Button {
                            playlistItems = [track]
                            showingPlaylistPicker = true
                        } label: {
                            Label("Add to Server Playlist", systemImage: "music.note.list")
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .resonanceBrowseBottomClearance()
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
        }
    }
}

struct RemoteArtistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
    @EnvironmentObject private var layeredNavigationState: ResonanceLayerNavigation
    @State private var presentedAlbum: RemoteAlbum?
    @State private var showingAllAlbums = false
    @State private var showingLibraryOptions = false
    let artist: RemoteArtist

    private var sortedAlbums: [RemoteAlbum] {
        switch settings.artistAlbumSort {
        case .title:
            artist.albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .newest:
            artist.albums.sorted {
                if $0.releaseYear == $1.releaseYear {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.releaseYear > $1.releaseYear
            }
        case .oldest:
            artist.albums.sorted {
                if $0.releaseYear == $1.releaseYear {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                if $0.releaseYear == 0 { return false }
                if $1.releaseYear == 0 { return true }
                return $0.releaseYear < $1.releaseYear
            }
        }
    }

    private var allTracks: [RemoteTrackItem] {
        artist.albums.flatMap(\.tracks).sorted { lhs, rhs in
            let albumComparison = lhs.album.localizedStandardCompare(rhs.album)
            if albumComparison != .orderedSame { return albumComparison == .orderedAscending }
            if lhs.discNumber != rhs.discNumber { return lhs.discNumber < rhs.discNumber }
            if lhs.trackNumber != rhs.trackNumber { return lhs.trackNumber < rhs.trackNumber }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private var indexedAlbumSections: [ArtistIndexSection<RemoteAlbum>] {
        let grouped = Dictionary(grouping: sortedAlbums) { resonanceArtistIndexKey($0.title) }
        let order = resonanceArtistIndexOrder(
            for: Array(grouped.keys),
            ascending: true
        )
        return order.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            return ArtistIndexSection(key: key, items: values)
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    @ViewBuilder
    private func allAlbumsTile() -> some View {
        Button {
            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
            if layeredNavigation {
                layeredNavigationState.showRemoteAllAlbums(
                    artistName: artist.name,
                    tracks: allTracks
                )
            } else {
                showingAllAlbums = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RemoteArtwork(
                        context: RemoteArtworkContext(artist),
                        size: settings.libraryThumbnailSize.gridArtworkPoints,
                    )
                    Color.black.opacity(0.28)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                Text("All Albums")
                    .font(settings.libraryTextSize.font.weight(.semibold))
                Text("\(allTracks.count) tracks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contextMenu {
            Button {
                downloads.requestDownload(allTracks, into: library)
            } label: {
                Label("Download Artist", systemImage: "arrow.down.circle")
            }
        }
    }

    @ViewBuilder
    private func albumTile(_ album: RemoteAlbum) -> some View {
        Button {
            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
            layeredNavigationState.remoteAlbum = album
            layeredNavigationState.layer = .album
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RemoteArtwork(
                    context: RemoteArtworkContext(album),
                    size: settings.libraryThumbnailSize.gridArtworkPoints,
                )
                Text(album.title)
                    .font(settings.libraryTextSize.font.weight(.semibold))
                    .lineLimit(1)
                Text(album.releaseYear > 0 ? String(album.releaseYear) : "Year unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contextMenu {
            Button {
                downloads.requestDownload(album.tracks, into: library)
            } label: {
                Label("Download Album", systemImage: "arrow.down.circle")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        ResonanceHeroActionButton(title: "Play", systemImage: "play.fill", tint: settings.accentColor, prominent: true) {
                            Task { await remote.playArtist(artist, using: player) }
                        }
                        ResonanceHeroActionButton(title: "Shuffle", systemImage: "shuffle", tint: settings.accentColor, prominent: false) {
                            Task { await remote.playArtist(artist, using: player, shuffle: true) }
                        }
                    }

                    RemoteArtwork(
                        context: RemoteArtworkContext(artist),
                        size: 158,
                    )

                    VStack(spacing: 6) {
                        RemoteDownloadHeroMenu(scope: "Artist", tracks: allTracks)
                        ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                            Task { await remote.addToQueue(allTracks, using: player) }
                        }
                    }
                }
                Text(artist.name)
                    .font(.title3.bold())
                    .lineLimit(1)
            }
            .resonanceHeroSurface()

            VStack(spacing: 2) {
                Picker("Album sort", selection: $settings.artistAlbumSort) {
                    ForEach(ArtistAlbumSort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                ArtistAlbumLayoutToggle()
            }
            .padding(.horizontal)
            .padding(.vertical, 1)
            .background {
                ResonanceThemeSurfaceBackdrop()
            }

            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    Group {
                        if settings.artistAlbumLayout == .grid && settings.albumLayout == .grid {
                            ScrollView {
                                ResonanceAlphabetGrid(
                                    sections: indexedAlbumSections,
                                    columns: columns,
                                    sectionIDPrefix: "artist-album-section",
                                sectionLabelColor: settings.textAccentColor,
                                    leadingCellCount: 1,
                                    leadingContent: AnyView(allAlbumsTile())
                                ) { album in
                                    albumTile(album)
                                }
                                .padding(.leading, 16)
                                .padding(.trailing, 36)
                                .padding(.bottom)
                            }
                            .background {
                                ResonanceThemeSurfaceBackdrop()
                            }
                        } else {
                            List {
                                Button {
                                    guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                    if layeredNavigation {
                                        layeredNavigationState.showRemoteAllAlbums(
                                            artistName: artist.name,
                                            tracks: allTracks
                                        )
                                    } else {
                                        showingAllAlbums = true
                                    }
                                } label: {
                                    RemoteCollectionRow(
                                        title: "All Albums",
                                        subtitle: "\(allTracks.count) tracks, grouped by album",
                                        artwork: RemoteArtworkContext(artist),
                                        large: settings.albumLayout == .large,
                                    )
                                }
                                .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                .listRowBackground(Color.clear)

                                ForEach(indexedAlbumSections, id: \.key) { section in
                                    Section {
                                        ForEach(section.items) { album in
                                            Button {
                                                guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                                layeredNavigationState.remoteAlbum = album
                                                layeredNavigationState.layer = .album
                                            } label: {
                                                RemoteCollectionRow(
                                                    title: album.title,
                                                    subtitle: album.releaseYear > 0 ? "\(album.artist) • \(album.releaseYear)" : "Release date unavailable",
                                                    artwork: RemoteArtworkContext(album),
                                                    large: settings.albumLayout == .large,
                                                )
                                            }
                                            .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                            .listRowBackground(Color.clear)
                                            .contextMenu {
                                                Button {
                                                    downloads.requestDownload(album.tracks, into: library)
                                                } label: {
                                                    Label("Download Album", systemImage: "arrow.down.circle")
                                                }
                                            }
                                        }
                                    } header: {
                                        Text(section.key)
                                            .foregroundStyle(settings.textAccentColor)
                                    }
                                    .id("artist-album-section-\(section.key)")
                                }
                            }
                            .listStyle(.plain)
                            .listRowBackground(Color.clear)
                            .scrollContentBackground(.hidden)
                            .safeAreaPadding(.trailing, 36)
                            .background(Color.clear)
                        }
                    }

                    if indexedAlbumSections.count > 1 {
                        VerticalArtistIndex(
                            keys: indexedAlbumSections.map(\.key),
                            diagnosticSurface: "streaming-artist-albums"
                        ) { key in
                            ResonanceDiagnostics.shared.recordDeferred(
                                "alphabet.scrollTo",
                                details: [
                                    "surface": "streaming-artist-albums",
                                    "key": key,
                                    "sectionCount": String(indexedAlbumSections.count)
                                ]
                            )
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("artist-album-section-\(key)", anchor: .top)
                            }
                        }
                        .zIndex(2)
                        .padding(.trailing, 1)
                        .padding(.vertical, 4)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background {
            ResonanceThemeBackdrop()
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailTabNavigation()
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                }

                ResonanceToolbarIconButton(
                    accessibilityLabel: "Streaming artist view and sort options",
                    systemImage: "slider.horizontal.3"
                ) {
                    showingLibraryOptions = true
                }

                Menu {
                    Button("Download Artist") {
                        downloads.requestDownload(allTracks, into: library)
                    }
                } label: {
                    ResonanceToolbarIconLabel(systemImage: "arrow.down.circle")
                }
                .accessibilityLabel("Download artist")

                Menu {
                    NavigationLink {
                        RemotePlaylistCollectionView()
                    } label: {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                } label: {
                    ResonanceToolbarIconLabel(systemImage: "music.note.list")
                }
                .disabled(settings.streamBackend != .subsonic)
                .accessibilityLabel("Open playlists")
            }
        }
        .sheet(isPresented: $showingLibraryOptions) {
            RemoteLibraryOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $presentedAlbum) { album in
            NavigationStack {
                RemoteAlbumDetailView(album: album)
            }
        }
        .fullScreenCover(isPresented: $showingAllAlbums) {
            NavigationStack {
                RemoteAllAlbumsTrackListView(artistName: artist.name, tracks: allTracks)
            }
        }
        .overlay(alignment: .top) {
            RemoteDownloadOverlay()
                .padding(.top, 52)
        }
        .resonanceTabSwipeObserver()
    }
}

private struct RemoteArtistActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let foreground: Color
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(foreground)
            .background(
                tint.opacity(isProminent ? 1 : 0.13),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(isProminent ? 0 : 0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "Download" ? "Download artist collection" : "\(title) artist")
    }
}

private struct RemoteDownloadHeroMenu: View {
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @EnvironmentObject private var library: LibraryStore

    let scope: String
    let tracks: [RemoteTrackItem]

    var body: some View {
        Menu {
            Button("Download \(scope)") {
                downloads.requestDownload(tracks, into: library)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.headline)
                Text("Download")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(Color.white)
            .background(
                Color.teal.opacity(0.13),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.teal.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Download \(scope)")
    }
}

struct RemoteAllAlbumsTrackListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @State private var playlistItems: [RemoteTrackItem] = []
    @State private var showingPlaylistPicker = false
    let artistName: String
    let tracks: [RemoteTrackItem]

    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        guard let first = tracks.first else { return }
                        await remote.play(first, in: tracks, using: player)
                    }
                } label: {
                    Label("Play All Albums", systemImage: "play.fill")
                        .foregroundStyle(settings.contrastingAccentTextColor)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.accentColor)
                .listRowBackground(Color.clear)
            }
            .listRowBackground(Color.clear)

            Section("Tracks") {
                ForEach(tracks) { track in
                    Button {
                        Task { await remote.play(track, in: tracks, using: player) }
                    } label: {
                        RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .remoteTrackSwipeActions(track)
                    .remoteTrackDownloadSwipeAction(track)
                    .contextMenu {
                        Button { Task { await remote.playNext([track], using: player) } } label: {
                            Label("Play Next", systemImage: "text.insert")
                        }
                        Button { Task { await remote.addToQueue([track], using: player) } } label: {
                            Label("Add to End of Queue", systemImage: "text.append")
                        }
                        Button { downloads.requestDownload([track], into: library) } label: {
                            Label("Download Track", systemImage: "arrow.down.circle")
                        }
                        if settings.streamBackend == .subsonic {
                            Button { Task { await remote.toggleFavorite(track, using: settings) } } label: {
                                Label(track.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: track.isFavorite ? "heart.slash" : "heart")
                            }
                            Button {
                                playlistItems = [track]
                                showingPlaylistPicker = true
                            } label: {
                                Label("Add to Server Playlist", systemImage: "music.note.list")
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .background {
            ResonanceThemeBackdrop()
        }
        .navigationTitle("\(artistName) — All Albums")
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
        }
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailTabNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !layeredNavigation {
                    Button { dismiss() } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .overlay(alignment: .top) {
            RemoteDownloadOverlay()
                .padding(.top, 52)
        }
        .resonanceTabSwipeObserver()
    }
}

struct RemoteAlbumDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @State private var playlistItems: [RemoteTrackItem] = []
    @State private var showingPlaylistPicker = false
    @State private var showingAlbumOptions = false
    @State private var showingArtworkSearch = false
    @State private var artworkData: Data?
    @State private var resolvedArtworkData: Data?
    @State private var isAutomaticallySelectedArtwork = false
    let album: RemoteAlbum

    private var albumHero: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 10) {
                    ResonanceHeroActionButton(title: "Play", systemImage: "play.fill", tint: settings.accentColor, prominent: true) {
                        Task { await remote.playAlbum(album, using: player) }
                    }
                    RemoteDownloadHeroMenu(scope: "Album", tracks: album.tracks)
                }

                RemoteArtwork(
                    context: RemoteArtworkContext(album),
                    size: 176,
                    overrideData: artworkData ?? resolvedArtworkData,
                    showWarningBorder: artworkData != nil || isAutomaticallySelectedArtwork
                )

                VStack(spacing: 10) {
                    ResonanceHeroActionButton(title: "Play Next", systemImage: "text.insert", tint: settings.accentColor, prominent: false) {
                        Task { await remote.playNext(album.tracks, using: player) }
                    }
                    ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                        Task { await remote.addToQueue(album.tracks, using: player) }
                    }
                }
            }

            Text(album.title)
                .font(.title3.bold())
                .lineLimit(1)
            Text(album.releaseYear > 0 ? "\(album.artist) • \(album.releaseYear)" : album.artist)
                .font(.caption)
                .foregroundStyle(settings.themeSecondaryColor)
                .lineLimit(1)
        }
        .resonanceHeroSurface()
        .resonanceTabSwipeObserver()
    }

    @ViewBuilder
    private func trackRow(_ track: RemoteTrackItem) -> some View {
        Button {
            Task { await remote.play(track, in: album.tracks, using: player) }
        } label: {
            RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
        }
        .buttonStyle(.plain)
        .remoteTrackSwipeActions(track)
        .remoteTrackDownloadSwipeAction(track)
        .contextMenu {
            Button { Task { await remote.playNext([track], using: player) } } label: {
                Label("Play Next", systemImage: "text.insert")
            }
            Button { Task { await remote.addToQueue([track], using: player) } } label: {
                Label("Add to End of Queue", systemImage: "text.append")
            }
            Button { downloads.requestDownload([track], into: library) } label: {
                Label("Download Track", systemImage: "arrow.down.circle")
            }
            if settings.streamBackend == .subsonic {
                Button { Task { await remote.toggleFavorite(track, using: settings) } } label: {
                    Label(
                        track.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: track.isFavorite ? "heart.slash" : "heart"
                    )
                }
                Button {
                    playlistItems = [track]
                    showingPlaylistPicker = true
                } label: {
                    Label("Add to Server Playlist", systemImage: "music.note.list")
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            albumHero
            List {
                Section("Tracks") {
                    ForEach(album.tracks) { track in
                        trackRow(track)
                    }
                    .listRowBackground(Color.clear)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .background {
                ResonanceThemeSurfaceBackdrop()
            }
        }
        .background {
            ResonanceThemeBackdrop()
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailTabNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !layeredNavigation {
                    Button { dismiss() } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Album options",
                    systemImage: "ellipsis.circle"
                ) {
                    showingAlbumOptions = true
                }
            }
        }
        .confirmationDialog(
            "Album Options",
            isPresented: $showingAlbumOptions,
            titleVisibility: .visible
        ) {
            Button("Play Album Next") {
                Task { await remote.playNext(album.tracks, using: player) }
            }
            Button("Add Album to End of Queue") {
                Task { await remote.addToQueue(album.tracks, using: player) }
            }
            Button("Download Album") {
                downloads.requestDownload(album.tracks, into: library)
            }
            Button("Choose Album Artwork") {
                showingArtworkSearch = true
            }
            if settings.streamBackend == .subsonic {
                Button("Add Album to Server Playlist") {
                    playlistItems = album.tracks
                    showingPlaylistPicker = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
        }
        .sheet(isPresented: $showingArtworkSearch) {
            OnlineArtworkSearchSheet(
                artist: album.artist,
                albumArtist: album.artist,
                album: album.title,
                onApplyToApp: { data in
                    artworkData = data
                    downloads.rememberArtwork(data, for: album.tracks)
                },
                onSaveToFiles: { data in
                    artworkData = data
                    downloads.rememberArtwork(data, for: album.tracks)
                    return nil
                }
            )
        }
        .overlay(alignment: .top) {
            RemoteDownloadOverlay()
                .padding(.top, 52)
        }
        .task(id: "\(album.id)|\(album.artworkURL?.absoluteString ?? "")|\(album.artworkBase64 != nil)") {
            let hasProvidedArtwork = RemoteArtworkContext(album).hasProvidedArtwork
            let automaticArtwork = await StreamingArtworkCache.shared.artwork(
                artist: album.artist,
                album: album.title,
                trackQueries: streamingArtworkQueries(album.tracks)
            )
            guard !Task.isCancelled else { return }
            if let automaticArtwork {
                resolvedArtworkData = automaticArtwork
                isAutomaticallySelectedArtwork = !hasProvidedArtwork
                if !hasProvidedArtwork {
                    downloads.rememberArtwork(automaticArtwork, for: album.tracks)
                }
            } else if let firstTrack = album.tracks.first,
                      let existingArtwork = await remote.artworkData(for: firstTrack) {
                resolvedArtworkData = existingArtwork
                isAutomaticallySelectedArtwork = false
            }
        }
    }
}

private struct RemotePlaylistCollectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var playlistToDelete: RemotePlaylist?
    @State private var playlistToRename: RemotePlaylist?
    @State private var renameText = ""

    var body: some View {
        List {
            Section {
                Button {
                    newName = ""
                    showingCreate = true
                } label: {
                    Label("Add a Playlist", systemImage: "plus.circle.fill")
                }
            }

            Section("Server Playlists") {
                if remote.filteredPlaylists.isEmpty {
                    ContentUnavailableView(
                        "No Server Playlists",
                        systemImage: "music.note.list",
                        description: Text("Create a playlist here or refresh playlists from Navidrome.")
                    )
                } else {
                    ForEach(remote.filteredPlaylists) { playlist in
                        NavigationLink {
                            RemotePlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            RemoteCollectionRow(
                                title: playlist.name,
                                subtitle: "\(playlist.tracks.count) tracks • \(formatDuration(playlist.duration))",
                                artwork: RemoteArtworkContext(playlist),
                                large: false
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { playlistToDelete = playlist } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                playlistToRename = playlist
                                renameText = playlist.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(settings.accentColor)
                        }
                        .contextMenu {
                            Button {
                                playlistToRename = playlist
                                renameText = playlist.name
                            } label: {
                                Label("Rename Playlist", systemImage: "pencil")
                            }
                            Button(role: .destructive) { playlistToDelete = playlist } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Streaming Playlists")
        .searchable(text: $remote.playlistSearchText, prompt: "Search server playlists")
        .refreshable { await remote.refreshPlaylists(using: settings) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await remote.refreshPlaylists(using: settings) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if remote.playlists.isEmpty { await remote.refreshPlaylists(using: settings) }
        }
        .alert("New Server Playlist", isPresented: $showingCreate) {
            TextField("Playlist name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                Task { _ = await remote.createPlaylist(named: newName, using: settings) }
            }
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Rename Server Playlist", isPresented: Binding(
            get: { playlistToRename != nil },
            set: { if !$0 { playlistToRename = nil } }
        )) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) { playlistToRename = nil }
            Button("Rename") {
                if let playlist = playlistToRename {
                    Task { _ = await remote.renamePlaylist(playlist, to: renameText, using: settings) }
                }
                playlistToRename = nil
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog(
            "Delete Playlist?",
            isPresented: Binding(
                get: { playlistToDelete != nil },
                set: { if !$0 { playlistToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) {
                if let playlist = playlistToDelete {
                    Task { _ = await remote.deletePlaylist(playlist, using: settings) }
                }
                playlistToDelete = nil
            }
            Button("Cancel", role: .cancel) { playlistToDelete = nil }
        } message: {
            Text("This deletes the playlist from Navidrome but does not delete its audio files.")
        }
    }
}

private struct RemotePlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: RemoteDownloadManager
    @State private var editMode: EditMode = .inactive
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingDelete = false
    let playlistID: String

    private var playlist: RemotePlaylist? { remote.playlists.first { $0.id == playlistID } }

    var body: some View {
        Group {
            if let playlist {
                List {
                    Section {
                        HStack(alignment: .top, spacing: 14) {
                            RemoteArtwork(context: RemoteArtworkContext(playlist), size: 116)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(playlist.name).font(.title2.bold())
                                Text("\(playlist.tracks.count) tracks")
                                    .foregroundStyle(.secondary)
                                Button {
                                    Task { await remote.playPlaylist(playlist, using: player) }
                                } label: {
                                    Label("Play Playlist", systemImage: "play.fill")
                                        .foregroundStyle(settings.contrastingAccentTextColor)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(settings.accentColor)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Section("Tracks") {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            Button {
                                Task { await remote.play(track, in: playlist.tracks, using: player) }
                            } label: {
                                RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
                            }
                            .buttonStyle(.plain)
                            .remoteTrackSwipeActions(track)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    downloads.requestDownload([track], into: library)
                                } label: {
                                    Label("Download", systemImage: "arrow.down.circle")
                                }
                                .tint(.green)

                                Button(role: .destructive) {
                                    Task { _ = await remote.removeTrack(at: index, from: playlist, using: settings) }
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                        }
                        .onMove { offsets, destination in
                            var reordered = playlist.tracks
                            reordered.move(fromOffsets: offsets, toOffset: destination)
                            Task {
                                _ = await remote.replacePlaylistOrder(playlist, with: reordered, using: settings)
                            }
                        }
                    }
                }
                .environment(\.editMode, $editMode)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                renameText = playlist.name
                                showingRename = true
                            } label: {
                                Label("Rename Playlist", systemImage: "pencil")
                            }
                            Button(role: .destructive) { showingDelete = true } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .navigationTitle(playlist.name)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Rename Server Playlist", isPresented: $showingRename) {
                    TextField("Playlist name", text: $renameText)
                    Button("Cancel", role: .cancel) {}
                    Button("Rename") {
                        Task { _ = await remote.renamePlaylist(playlist, to: renameText, using: settings) }
                    }
                }
                .confirmationDialog("Delete Playlist?", isPresented: $showingDelete, titleVisibility: .visible) {
                    Button("Delete Playlist", role: .destructive) {
                        Task {
                            if await remote.deletePlaylist(playlist, using: settings) { dismiss() }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This deletes the playlist from Navidrome, not the audio files.")
                }
            } else {
                ContentUnavailableView("Playlist Not Found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

private struct RemotePlaylistPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var isSaving = false
    let items: [RemoteTrackItem]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingCreate = true
                    } label: {
                        Label("Add a Playlist", systemImage: "plus.circle.fill")
                    }
                }

                Section("Choose a Server Playlist") {
                    if remote.playlists.isEmpty {
                        ContentUnavailableView(
                            "No Server Playlists",
                            systemImage: "music.note.list",
                            description: Text("Tap Add a Playlist, then select it here.")
                        )
                    } else {
                        ForEach(remote.playlists) { playlist in
                            Button {
                                guard !isSaving else { return }
                                isSaving = true
                                Task {
                                    let saved = await remote.add(items, to: playlist, using: settings)
                                    isSaving = false
                                    if saved { dismiss() }
                                }
                            } label: {
                                RemoteCollectionRow(
                                    title: playlist.name,
                                    subtitle: "\(playlist.tracks.count) tracks",
                                    artwork: RemoteArtworkContext(playlist),
                                    large: false
                                )
                            }
                            .disabled(isSaving)
                        }
                    }
                }
            }
            .navigationTitle("Add to Server Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if remote.playlists.isEmpty { await remote.refreshPlaylists(using: settings) }
            }
            .alert("New Server Playlist", isPresented: $showingCreate) {
                TextField("Playlist name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    Task {
                        let created = await remote.createPlaylist(named: newName, using: settings)
                        if created, let playlist = remote.playlists.first(where: {
                            $0.name.caseInsensitiveCompare(newName.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                        }) {
                            _ = await remote.add(items, to: playlist, using: settings)
                            dismiss()
                        }
                    }
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct RemoteCollectionRow: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let subtitle: String
    let artwork: RemoteArtworkContext
    let large: Bool

    init(
        title: String,
        subtitle: String,
        artwork: RemoteArtworkContext,
        large: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
        self.large = large
    }

    var body: some View {
        HStack(spacing: large ? 12 : 8) {
            RemoteArtwork(
                context: artwork,
                size: large ? max(76, settings.libraryThumbnailSize.points * 2) : settings.libraryThumbnailSize.points,
            )
            VStack(alignment: .leading, spacing: large ? 4 : 1) {
                Text(title)
                    .font(settings.libraryTextSize.font.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(large ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, large ? 2 : 0)
    }
}

private struct RemoteTrackRow: View {
    let track: RemoteTrackItem
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(.tint)
                    .frame(width: 18)
            } else {
                Text(track.trackNumber > 0 ? String(track.trackNumber) : "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            RemoteArtwork(
                context: RemoteArtworkContext(track),
                size: 42,
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).lineLimit(1)
                Text("\(track.artist) • \(track.album)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if track.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(track.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if track.fileSizeBytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: track.fileSizeBytes, countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

private final class RemoteArtworkImageBox: NSObject, @unchecked Sendable {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}

private actor RemoteArtworkLoader {
    static let shared = RemoteArtworkLoader()

    private let thumbnails = NSCache<NSString, RemoteArtworkImageBox>()
    private let sourceData = NSCache<NSString, NSData>()

    init() {
        thumbnails.countLimit = 600
        thumbnails.totalCostLimit = 96 * 1024 * 1024
    }

    func image(
        data: Data?,
        url: URL?,
        base64: String?,
        sourceKey: String,
        maxPixelSize: Int
    ) async -> RemoteArtworkImageBox? {
        let boundedPixelSize = min(1536, max(96, maxPixelSize))
        let thumbnailKey = "\(sourceKey)|\(boundedPixelSize)" as NSString
        if let cached = thumbnails.object(forKey: thumbnailKey) { return cached }

        guard let imageData = await self.data(
            data: data,
            url: url,
            base64: base64,
            sourceKey: sourceKey
        ) else { return nil }

        let box = await Task.detached(priority: .utility) {
            Self.downsample(data: imageData, maxPixelSize: boundedPixelSize)
        }.value
        guard let box else { return nil }
        let cost = max(1, box.image.bytesPerRow * box.image.height)
        thumbnails.setObject(box, forKey: thumbnailKey, cost: cost)
        return box
    }

    func data(
        data: Data?,
        url: URL?,
        base64: String?,
        sourceKey: String
    ) async -> Data? {
        let key = sourceKey as NSString
        if let cached = sourceData.object(forKey: key) { return cached as Data }

        let imageData: Data
        if let data {
            imageData = data
        } else if let base64 {
            guard let decoded = Data(base64Encoded: base64) else { return nil }
            imageData = decoded
        } else if let url {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 20
                let (downloaded, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { return nil }
                imageData = downloaded
            } catch {
                return nil
            }
        } else {
            return nil
        }
        guard !imageData.isEmpty else { return nil }
        sourceData.setObject(imageData as NSData, forKey: key, cost: imageData.count)
        return imageData
    }

    nonisolated private static func downsample(data: Data, maxPixelSize: Int) -> RemoteArtworkImageBox? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return RemoteArtworkImageBox(image)
    }
}

private struct RemoteArtworkSource: Hashable {
    let url: URL?
    let base64: String?

    var cacheKey: String {
        if let url { return url.absoluteString }
        if let base64 {
            return "base64:\(base64.prefix(32)):\(base64.hashValue)"
        }
        return "empty"
    }
}

private struct RemoteArtworkContext: Hashable {
    let sources: [RemoteArtworkSource]
    let fallbackArtist: String?
    let fallbackAlbum: String?
    let fallbackTrackQueries: [StreamingArtworkTrackQuery]
    let preferOnlineSearch: Bool

    var hasProvidedArtwork: Bool { !sources.isEmpty }

    init(
        url: URL?,
        base64: String?,
        fallbackArtist: String? = nil,
        fallbackAlbum: String? = nil,
        fallbackTrackQueries: [StreamingArtworkTrackQuery] = [],
        preferOnlineSearch: Bool = false
    ) {
        self.sources = [RemoteArtworkSource(url: url, base64: base64)]
            .filter { $0.url != nil || $0.base64 != nil }
        self.fallbackArtist = fallbackArtist
        self.fallbackAlbum = fallbackAlbum
        self.fallbackTrackQueries = fallbackTrackQueries
        self.preferOnlineSearch = preferOnlineSearch
    }

    private init(
        sources: [RemoteArtworkSource],
        fallbackArtist: String?,
        fallbackAlbum: String?,
        fallbackTrackQueries: [StreamingArtworkTrackQuery],
        preferOnlineSearch: Bool
    ) {
        self.sources = sources
        self.fallbackArtist = fallbackArtist
        self.fallbackAlbum = fallbackAlbum
        self.fallbackTrackQueries = fallbackTrackQueries
        self.preferOnlineSearch = preferOnlineSearch
    }

    private static func sources(from tracks: [RemoteTrackItem]) -> [RemoteArtworkSource] {
        var seen = Set<RemoteArtworkSource>()
        var result: [RemoteArtworkSource] = []
        for track in tracks {
            let source = RemoteArtworkSource(url: track.artworkURL, base64: track.artworkBase64)
            guard (source.url != nil || source.base64 != nil), seen.insert(source).inserted else { continue }
            result.append(source)
            if result.count == 12 { break }
        }
        return result
    }

    init(_ track: RemoteTrackItem) {
        self.init(sources: Self.sources(from: [track]),
            fallbackArtist: track.albumArtist.isEmpty ? track.artist : track.albumArtist,
            fallbackAlbum: track.album,
            fallbackTrackQueries: streamingArtworkQueries([track]),
            preferOnlineSearch: true
        )
    }

    init(_ album: RemoteAlbum) {
        self.init(sources: Self.sources(from: album.tracks),
            fallbackArtist: album.artist,
            fallbackAlbum: album.title,
            fallbackTrackQueries: streamingArtworkQueries(album.tracks),
            preferOnlineSearch: true
        )
    }

    init(_ artist: RemoteArtist) {
        self.init(sources: Self.sources(from: artist.tracks),
            fallbackArtist: artist.name,
            fallbackAlbum: nil,
            fallbackTrackQueries: streamingArtworkQueries(artist.tracks),
            preferOnlineSearch: true
        )
    }

    init(_ playlist: RemotePlaylist) {
        self.init(
            sources: Self.sources(from: playlist.tracks),
            fallbackArtist: nil,
            fallbackAlbum: nil,
            fallbackTrackQueries: [],
            preferOnlineSearch: false
        )
    }
}

private struct RemoteArtwork: View {
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var settings: AppSettings

    let context: RemoteArtworkContext
    let size: CGFloat
    let overrideData: Data?
    let showWarningBorder: Bool

    init(
        context: RemoteArtworkContext,
        size: CGFloat,
        overrideData: Data? = nil,
        showWarningBorder: Bool = false
    ) {
        self.context = context
        self.size = size
        self.overrideData = overrideData
        self.showWarningBorder = showWarningBorder
    }

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var automaticallySelectedData: Data?

    private var sourceKey: String {
        if let overrideData {
            return "override:\(overrideData.count):\(overrideData.prefix(16).base64EncodedString())"
        }
        if let automaticallySelectedData {
            return "automatic:\(automaticallySelectedData.count):\(automaticallySelectedData.prefix(16).base64EncodedString())"
        }
        if let source = context.sources.first { return source.cacheKey }
        return "placeholder"
    }

    private var taskKey: String {
        "\(context.sources.hashValue)|\(overrideData?.count ?? 0)|\(context.fallbackArtist ?? "")|\(context.fallbackAlbum ?? "")|\(context.fallbackTrackQueries.hashValue)|\(Int((size * displayScale).rounded(.up)))"
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
                if isLoading && !didFail { ProgressView().controlSize(.small) }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: max(7, size * 0.09)))
        .overlay {
            if settings.showArtworkWarning,
               !context.hasProvidedArtwork,
               (showWarningBorder || automaticallySelectedData != nil) {
                RoundedRectangle(cornerRadius: max(7, size * 0.09)).stroke(.red, lineWidth: 2)
            }
        }
        .task(id: taskKey) { await loadArtwork() }
    }

    @MainActor
    private func loadArtwork() async {
        isLoading = true
        didFail = false
        automaticallySelectedData = nil
        defer { isLoading = false }

        let pixels = Int((size * displayScale).rounded(.up))
        var loaded: RemoteArtworkImageBox?
        if let overrideData {
            let overrideLoadedData = await RemoteArtworkLoader.shared.data(
                data: overrideData,
                url: nil,
                base64: nil,
                sourceKey: sourceKey
            )
            if overrideLoadedData != nil {
                loaded = await RemoteArtworkLoader.shared.image(
                    data: overrideLoadedData,
                    url: nil,
                    base64: nil,
                    sourceKey: sourceKey,
                    maxPixelSize: pixels
                )
            }
        } else {
            if context.preferOnlineSearch {
                let automaticData = await StreamingArtworkCache.shared.artwork(
                    artist: context.fallbackArtist ?? "",
                    album: context.fallbackAlbum,
                    trackQueries: context.fallbackTrackQueries
                )
                guard !Task.isCancelled else { return }
                if let automaticData {
                    automaticallySelectedData = automaticData
                    let automaticKey = sourceKey
                    if let automaticImage = await RemoteArtworkLoader.shared.image(
                        data: automaticData,
                        url: nil,
                        base64: nil,
                        sourceKey: automaticKey,
                        maxPixelSize: pixels
                    ) {
                        image = UIImage(cgImage: automaticImage.image, scale: displayScale, orientation: .up)
                        return
                    }
                    automaticallySelectedData = nil
                }
            }

            for source in context.sources {
                let candidateData = await RemoteArtworkLoader.shared.data(
                    data: nil,
                    url: source.url,
                    base64: source.base64,
                    sourceKey: source.cacheKey
                )
                let candidateImage = await RemoteArtworkLoader.shared.image(
                    data: candidateData,
                    url: nil,
                    base64: nil,
                    sourceKey: source.cacheKey,
                    maxPixelSize: pixels
                )
                if let candidateImage {
                    loaded = candidateImage
                    break
                }
            }
        }
        guard !Task.isCancelled else { return }
        if let loaded {
            image = UIImage(cgImage: loaded.image, scale: displayScale, orientation: .up)
            return
        }

        guard let fallbackArtist = context.fallbackArtist,
              !fallbackArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            image = nil
            didFail = true
            return
        }

        let fallbackData = await StreamingArtworkCache.shared.artwork(
            artist: fallbackArtist,
            album: context.fallbackAlbum,
            trackQueries: context.fallbackTrackQueries
        )
        guard !Task.isCancelled else { return }
        automaticallySelectedData = fallbackData
        if let fallbackData,
           let fallbackImage = await RemoteArtworkLoader.shared.image(
                data: fallbackData,
                url: nil,
                base64: nil,
                sourceKey: sourceKey,
                maxPixelSize: pixels
           ) {
            image = UIImage(cgImage: fallbackImage.image, scale: displayScale, orientation: .up)
        } else {
            image = nil
            didFail = true
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(7, size * 0.09)).fill(.secondary.opacity(0.15))
            Image(systemName: "music.note").foregroundStyle(.secondary)
        }
    }
}

private func streamingArtworkQueries(_ tracks: [RemoteTrackItem]) -> [StreamingArtworkTrackQuery] {
    tracks.map {
        StreamingArtworkTrackQuery(
            artist: $0.artist,
            albumArtist: $0.albumArtist,
            album: $0.album,
            title: $0.title
        )
    }
}

private func formatDuration(_ duration: Double) -> String {
    guard duration.isFinite, duration > 0 else { return "—:—" }
    let seconds = Int(duration.rounded())
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
