import SwiftUI

struct AlbumDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showingPlaylistPicker = false
    @State private var showingMetadataEditor = false
    @State private var showingRemovalOptions = false
    @State private var showingAlbumOptions = false
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

    private var albumHero: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 10) {
                    ResonanceHeroActionButton(title: "Play", systemImage: "play.fill", tint: settings.accentColor, prominent: true) {
                        if let first = liveAlbum.tracks.first {
                            player.play(first, in: liveAlbum.tracks)
                        }
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

                VStack(spacing: 10) {
                    ResonanceHeroActionButton(title: "Play Next", systemImage: "text.insert", tint: settings.accentColor, prominent: false) {
                        player.playNext(liveAlbum.tracks)
                    }
                    ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                        player.addToQueue(liveAlbum.tracks)
                    }
                }
            }

            Text(liveAlbum.title)
                .font(.title3.bold())
                .lineLimit(1)
            Text(liveAlbum.artist)
                .font(.caption)
                .foregroundStyle(settings.themeSecondaryColor)
        }
        .resonanceHeroSurface()
        .contentShape(Rectangle())
        .resonanceTopDownDismiss { dismiss() }
        .contextMenu {
            Button { showingMetadataEditor = true } label: {
                Label("Edit Album Metadata", systemImage: "pencil")
            }
            Divider()
            Button { showingRemovalOptions = true } label: {
                Label("Remove or Delete Album", systemImage: "trash")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            albumHero
            List {
                Section("Tracks") {
                    ForEach(liveAlbum.tracks) { track in
                        Button { player.play(track, in: liveAlbum.tracks) } label: {
                            TrackListRow(
                                track: track,
                                leadingNumber: track.trackNumber > 0 ? "\(track.trackNumber)" : "–",
                                showsArtwork: true,
                                large: false,
                                showsAlbum: false
                            )
                        }
                        .buttonStyle(.plain)
                        .trackLibraryActions(track)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                ResonanceThemeSurfaceBackdrop()
            }
        }
        .navigationTitle(liveAlbum.title)
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailBottomSpace()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Album options",
                    systemImage: "ellipsis.circle"
                ) {
                    showingAlbumOptions = true
                }

                Button { showingMetadataEditor = true } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit album metadata")

                Button { library.toggleFavorite(liveAlbum) } label: {
                    Image(systemName: library.isAlbumFavorite(liveAlbum) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(library.isAlbumFavorite(liveAlbum) ? "Remove album from favorites" : "Add album to favorites")

                Button {
                    showingPlaylistPicker = true
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .accessibilityLabel(library.playlists.isEmpty ? "Add a playlist" : "Add album to playlist")
                Button { showingRemovalOptions = true } label: {
                    Image(systemName: "trash")
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Remove or delete album")
            }
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            PlaylistPickerSheet(tracks: liveAlbum.tracks)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMetadataEditor) {
            AlbumMetadataEditorSheet(album: liveAlbum)
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
                    } else if value.startLocation.y < 120,
                              value.translation.height > 70,
                              abs(value.translation.height) > abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
}

struct AllAlbumsTrackListView: View {
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var settings: AppSettings
    let artistName: String
    let tracks: [Track]

    var body: some View {
        List {
            if let first = tracks.first {
                Section {
                    Button { player.play(first, in: tracks) } label: {
                        Label("Play All Albums", systemImage: "play.fill")
                            .foregroundStyle(settings.contrastingAccentTextColor)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.accentColor)
                }
            }

            ForEach(Array(Dictionary(grouping: tracks, by: \.album).keys.sorted()), id: \.self) { albumName in
                Section(albumName) {
                    ForEach(tracks.filter { $0.album == albumName }) { track in
                        Button { player.play(track, in: tracks) } label: {
                            TrackListRow(
                                track: track,
                                leadingNumber: track.trackNumber > 0 ? "\(track.trackNumber)" : "–",
                                showsArtwork: true,
                                large: false,
                                showsAlbum: false
                            )
                        }
                        .buttonStyle(.plain)
                        .trackLibraryActions(track)
                    }
                }
            }
        }
        .navigationTitle("All Albums")
        .navigationBarTitleDisplayMode(.inline)
        .resonanceDetailBottomSpace()
        .safeAreaInset(edge: .top, spacing: 0) {
            Text(artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(.bar)
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

    var body: some View {
        HStack(spacing: large ? 12 : 8) {
            if showsArtwork {
                ArtworkView(
                    data: library.artworkData(for: track),
                    embedded: library.artworkIsEmbedded(for: track),
                    size: large ? max(70, settings.libraryThumbnailSize.points * 1.8) : settings.libraryThumbnailSize.points
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
                } else {
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
