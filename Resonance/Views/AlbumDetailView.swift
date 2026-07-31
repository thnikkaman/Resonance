import SwiftUI

struct AlbumDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var layeredNavigationState: ResonanceLayerNavigation
    @State private var showingPlaylistPicker = false
    @State private var showingMetadataEditor = false
    @State private var showingArtworkSearch = false
    @State private var didOfferArtworkSearch = false
    @State private var showingRemovalOptions = false
    @State private var showingAlbumOptions = false
    @State private var showingLibraryOptions = false
    let album: Album

    private var liveTracks: [Track] {
        let albumKey = "\(album.artist)|\(album.title)"
        let matchingTracks = library.tracks.filter {
            "\($0.albumArtist)|\($0.album)".localizedCaseInsensitiveCompare(albumKey) == .orderedSame
        }
        let ids = Set(album.tracks.map(\.id))
        let currentTracks = matchingTracks.isEmpty
            ? library.tracks.filter { ids.contains($0.id) }
            : matchingTracks
        return currentTracks
            .sorted { ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title) }
    }

    private var liveAlbum: Album {
        let tracks = liveTracks.isEmpty ? album.tracks : liveTracks
        return Album(
            id: tracks.first.map { "\($0.albumArtist)|\($0.album)" } ?? album.id,
            title: tracks.first?.album ?? album.title,
            artist: tracks.first?.albumArtist ?? album.artist,
            tracks: tracks
        )
    }

    private var displayedTracks: [Track] { liveAlbum.tracks }

    private var albumHero: some View {
        ResonanceDetailHeroHeader(title: liveAlbum.title) {
            VStack(spacing: 4) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        ResonanceHeroActionButton(title: "Play", systemImage: "play.fill", tint: settings.accentColor, prominent: true) {
                            player.resumeAudiobookAlbum(
                                liveAlbum.tracks,
                                albumArtist: liveAlbum.artist,
                                album: liveAlbum.title
                            )
                        }
                        ResonanceHeroActionButton(
                            title: library.isAlbumFavorite(liveAlbum) ? "Unfavorite" : "Favorite",
                            systemImage: library.isAlbumFavorite(liveAlbum) ? "heart.fill" : "heart",
                            tint: settings.accentColor,
                            prominent: false
                        ) {
                            library.toggleFavorite(liveAlbum)
                        }
                    }

                    ArtworkView(
                        data: liveAlbum.artworkData,
                        embedded: liveAlbum.artworkIsEmbedded,
                        size: 176
                    )

                    VStack(spacing: 6) {
                        ResonanceHeroActionButton(title: "Play Next", systemImage: "text.insert", tint: settings.accentColor, prominent: false) {
                            player.playNext(liveAlbum.tracks)
                        }
                        ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                            player.addToQueue(liveAlbum.tracks)
                        }
                    }
                }
                Text(liveAlbum.artist)
                    .font(.caption)
                    .foregroundStyle(settings.themeSecondaryColor)
            }
            .resonanceHeroSurface()
            .contentShape(Rectangle())
            .contextMenu {
                Button { showingMetadataEditor = true } label: {
                    Label("Edit Album Metadata", systemImage: "pencil")
                }
                Button {
                    player.toggleAudiobook(albumArtist: liveAlbum.artist, album: liveAlbum.title)
                } label: {
                    Label(
                        player.isAudiobook(albumArtist: liveAlbum.artist, album: liveAlbum.title)
                            ? "Unmark as Audiobook"
                            : "Mark as Audiobook",
                        systemImage: player.isAudiobook(albumArtist: liveAlbum.artist, album: liveAlbum.title)
                            ? "book.closed.fill"
                            : "book.closed"
                    )
                }
                Divider()
                Button { showingRemovalOptions = true } label: {
                    Label("Remove or Delete Album", systemImage: "trash")
                }
            }
            .resonanceTabSwipeObserver()
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        let leadingNumber = track.trackNumber > 0 ? "\(track.trackNumber)" : "–"
        Button { player.play(track, in: liveAlbum.tracks) } label: {
            TrackListRow(track: track, leadingNumber: leadingNumber, showsArtwork: true, large: false, showsAlbum: false)
        }
        .buttonStyle(.plain)
        .trackLibraryActions(track)
    }

    var body: some View {
        VStack(spacing: 0) {
            albumHero
            List {
                Section("Tracks") {
                    ForEach(displayedTracks, id: \.id) { track in
                        trackRow(track)
                    }
                    .listRowBackground(Color.clear)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .background { ResonanceThemeSurfaceBackdrop() }
            .resonanceDetailBottomSpace()
        }
        .background {
            // The detail destination owns its page backdrop so the image stays
            // behind the hero and track list when pushed from Library.
            ResonanceThemeBackdrop()
        }
        .navigationTitle(liveAlbum.title)
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailTabNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !layeredNavigation {
                    ResonanceToolbarTextButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        width: 76,
                        action: { dismiss() }
                    )
                }
            }
            .resonanceHideSharedBackground()
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Album view settings",
                        systemImage: "slider.horizontal.3"
                    ) {
                        showingLibraryOptions = true
                    }

                    NavigationLink {
                        PlaylistCollectionView()
                    } label: {
                        ResonanceToolbarIconLabel(systemImage: "music.note.list")
                    }
                    .buttonStyle(.plain)
                    .help("Open playlists")
                    .accessibilityLabel("Open playlist manager, \(library.playlists.count) playlists")
                }
            }
            .resonanceHideSharedBackground()
            ToolbarItem(placement: .principal) {
                Button {
                    guard layeredNavigation else {
                        dismiss()
                        return
                    }
                    if layeredNavigationState.localArtist != nil {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            layeredNavigationState.showArtist()
                        }
                        return
                    }
                    guard let artist = library.artists.first(where: { candidate in
                        candidate.albums.contains(where: { $0.id == liveAlbum.id })
                            || candidate.name.localizedCaseInsensitiveCompare(liveAlbum.artist) == .orderedSame
                    }) else {
                        ResonanceDiagnostics.shared.recordDeferred(
                            "navigation.albumArtist.missing",
                            details: ["source": "library"]
                        )
                        return
                    }
                    layeredNavigationState.localArtist = artist
                    layeredNavigationState.remoteArtist = nil
                    withAnimation(.easeInOut(duration: 0.35)) {
                        layeredNavigationState.showArtist()
                    }
                } label: {
                    ResonanceHierarchyNavigationLabel(title: "Artist")
                }
                .accessibilityLabel("Artist, move up")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Edit album metadata",
                        systemImage: "pencil"
                    ) {
                        showingMetadataEditor = true
                    }

                    ResonanceToolbarIconButton(
                        accessibilityLabel: library.playlists.isEmpty ? "Add a playlist" : "Add album to playlist",
                        systemImage: "text.badge.plus"
                    ) {
                        showingPlaylistPicker = true
                    }

                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Open Settings",
                        systemImage: "gearshape"
                    ) {
                        layeredNavigationState.showSettings()
                    }
                }
            }
            .resonanceHideSharedBackground()
        }
        .sheet(isPresented: $showingLibraryOptions) {
            LibraryOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            PlaylistPickerSheet(tracks: liveAlbum.tracks)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMetadataEditor) {
            AlbumMetadataEditorSheet(album: liveAlbum)
        }
        .sheet(isPresented: $showingArtworkSearch) {
            OnlineArtworkSearchSheet(
                artist: liveAlbum.artist,
                albumArtist: liveAlbum.artist,
                album: liveAlbum.title,
                onApplyToApp: { data in
                    library.applyArtworkToApp(forAlbumTrackIDs: liveAlbum.tracks.map(\.id), data: data)
                },
                onSaveToFiles: { data in
                    library.updateAlbumMetadataInBackground(
                        trackIDs: liveAlbum.tracks.map(\.id),
                        album: liveAlbum.title,
                        artist: liveAlbum.tracks.first?.artist ?? liveAlbum.artist,
                        albumArtist: liveAlbum.artist,
                        discNumber: nil,
                        releaseYear: liveAlbum.releaseYear,
                        artworkData: data,
                        replaceArtwork: true
                    )
                    return nil
                }
            )
        }
        .task(id: "\(liveAlbum.id)|\(liveAlbum.artworkData == nil)") {
            guard liveAlbum.artworkData == nil, !didOfferArtworkSearch else { return }
            didOfferArtworkSearch = true
            showingArtworkSearch = true
        }
        .confirmationDialog(
            "Album Options",
            isPresented: $showingAlbumOptions,
            titleVisibility: .visible
        ) {
            Button("Play Album Next") {
                player.playNext(liveAlbum.tracks)
            }
            Button("Add Album to End of Queue") {
                player.addToQueue(liveAlbum.tracks)
            }
            Button("Edit Album Metadata") {
                showingMetadataEditor = true
            }
            Button(library.isAlbumFavorite(liveAlbum) ? "Remove from Favorites" : "Add to Favorites") {
                library.toggleFavorite(liveAlbum)
            }
            Button("Remove or Delete Album", role: .destructive) {
                showingRemovalOptions = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Remove \(liveAlbum.title)?",
            isPresented: $showingRemovalOptions,
            titleVisibility: .visible
        ) {
            Button("Remove from Library") {
                Task { await library.removeTracks(liveAlbum.tracks, deletingFiles: false) }
                dismiss()
            }
            Button("Delete from iPhone", role: .destructive) {
                Task { await library.removeTracks(liveAlbum.tracks, deletingFiles: true) }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove from Library keeps the audio files on your iPhone. Delete from iPhone permanently removes them.")
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 45)
                .onEnded { value in
                    if value.startLocation.x < 36 && value.translation.width > 70 {
                        dismiss()
                    }
                }
        )
    }
}

struct AllAlbumsTrackListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var layeredNavigationState: ResonanceLayerNavigation
    @State private var showingLibraryOptions = false
    let artistName: String
    let tracks: [Track]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                if let first = tracks.first {
                    ResonanceHeroActionButton(
                        title: "Play All Albums",
                        systemImage: "play.fill",
                        tint: settings.accentColor,
                        prominent: true
                    ) {
                        player.play(first, in: tracks)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: 29)
                    .padding(.bottom, 29)
                }

                ForEach(Array(Dictionary(grouping: tracks, by: \.album).keys.sorted()), id: \.self) { albumName in
                    Text(albumName)
                        .font(.headline)
                        .foregroundStyle(settings.textAccentColor)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    ForEach(tracks.filter { $0.album == albumName }) { track in
                        Button { player.play(track, in: tracks) } label: {
                            TrackListRow(track: track, leadingNumber: track.trackNumber > 0 ? "\(track.trackNumber)" : "–", showsArtwork: true, large: false, showsAlbum: false, showsArtist: false)
                        }
                        .buttonStyle(.plain)
                        .trackLibraryActions(track)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background { ResonanceThemeBackdrop() }
        .navigationTitle("All Albums")
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailTabNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !layeredNavigation {
                    ResonanceToolbarTextButton(
                        title: "Back",
                        systemImage: "chevron.left",
                        width: 76,
                        action: { dismiss() }
                    )
                }
            }
            .resonanceHideSharedBackground()
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Library view and sort options",
                        systemImage: "slider.horizontal.3"
                    ) {
                        showingLibraryOptions = true
                    }

                    NavigationLink {
                        PlaylistCollectionView()
                    } label: {
                        ResonanceToolbarIconLabel(systemImage: "music.note.list")
                    }
                    .buttonStyle(.plain)
                    .help("Open playlists")
                    .accessibilityLabel("Open playlist manager, \(library.playlists.count) playlists")
                }
            }
            .resonanceHideSharedBackground()
            ToolbarItem(placement: .principal) {
                Button {
                    if layeredNavigation {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            layeredNavigationState.showArtist()
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    ResonanceHierarchyNavigationLabel(title: "Artist")
                }
                .accessibilityLabel("Artist, move up")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Open Settings",
                    systemImage: "gearshape"
                ) {
                    layeredNavigationState.showSettings()
                }
            }
            .resonanceHideSharedBackground()
        }
        .sheet(isPresented: $showingLibraryOptions) {
            LibraryOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text(artistName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(settings.textAccentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .top)
            .background { ResonanceThemeSurfaceBackdrop() }
            .contentShape(Rectangle())
        }
    }

}

struct TrackListRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    let track: Track
    var leadingNumber: String? = nil
    var showsArtwork: Bool
    var large: Bool
    var showsAlbum: Bool
    var showsArtist: Bool = true

    var body: some View {
        HStack(spacing: large ? 12 : 8) {
            if showsArtwork {
                ArtworkView(
                    data: library.artworkData(for: track),
                    embedded: library.artworkIsEmbedded(for: track),
                    size: large ? max(70, settings.libraryThumbnailSize.points * 1.8) : settings.libraryThumbnailSize.points,
                    fallbackTrack: StreamingArtworkTrackQuery(
                        artist: track.artist,
                        albumArtist: track.albumArtist,
                        album: track.album,
                        title: track.title
                    )
                )
            }

            if let leadingNumber {
                Text(leadingNumber)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }

            PlayingTrackVisualizer(track: track)

            VStack(alignment: .leading, spacing: large ? 4 : 1) {
                HStack(spacing: 5) {
                    Text(track.title)
                        .font(settings.libraryTextSize.font.weight(.medium))
                        .lineLimit(1)
                    if library.hasMetadataOverride(track) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Metadata edited in Resonance")
                    }
                }
                if showsAlbum {
                    Text("\(track.artist) — \(track.album)")
                        .font(large ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if showsArtist {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
            if library.isFavorite(track) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Favorite")
            }
            Text(format(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct PlayingTrackVisualizer: View {
    @EnvironmentObject private var player: PlayerController
    let track: Track

    private var isCurrent: Bool { player.currentTrack?.id == track.id }
    private let heights: [CGFloat] = [8, 14, 6, 11]

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .frame(
                        width: 2,
                        height: isCurrent ? height : 2
                    )
            }
        }
        .frame(width: 13, height: 22)
        .foregroundStyle(isCurrent ? Color.accentColor : Color.clear)
        .accessibilityHidden(true)
    }
}

func format(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "—:—" }
    return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
}
