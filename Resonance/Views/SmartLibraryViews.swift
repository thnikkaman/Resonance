import SwiftUI
import PhotosUI
import UIKit

struct SmartTrackCollectionView: View {
    let title: String
    let tracks: [Track]
    let systemImage: String
    let emptyDescription: String

    var body: some View {
        if tracks.isEmpty {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(emptyDescription)
            )
        } else {
            VStack(spacing: 0) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                    Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)

                TrackCollectionView(tracks: tracks)
            }
        }
    }
}

struct PlaylistCollectionView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToDelete: UserPlaylist?
    @State private var searchText = ""

    private var visiblePlaylists: [UserPlaylist] {
        guard !searchText.isEmpty else { return library.playlists }
        return library.playlists.filter { playlist in
            if playlist.name.localizedCaseInsensitiveContains(searchText) { return true }
            return library.tracks(in: playlist.id).contains { track in
                [track.title, track.artist, track.albumArtist, track.album]
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    newPlaylistName = ""
                    showingNewPlaylist = true
                } label: {
                    Label("Add a Playlist", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }

            Section("Your Playlists") {
                if visiblePlaylists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "music.note.list",
                        description: Text("Tap Add a Playlist, then add tracks from a song, album, or Now Playing.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visiblePlaylists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            PlaylistRow(playlist: playlist)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                            } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search playlists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newPlaylistName = ""
                    showingNewPlaylist = true
                } label: {
                    Label("Add a Playlist", systemImage: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $showingNewPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                _ = library.createPlaylist(named: newPlaylistName)
            }
            .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for the new playlist.")
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
                if let playlistToDelete {
                    library.deletePlaylist(playlistToDelete.id)
                }
                playlistToDelete = nil
            }
            Button("Cancel", role: .cancel) { playlistToDelete = nil }
        } message: {
            Text("This removes the playlist but does not delete any music files.")
        }
    }
}

private struct PlaylistRow: View {
    @EnvironmentObject private var library: LibraryStore
    let playlist: UserPlaylist

    private var tracks: [Track] { library.tracks(in: playlist.id) }

    var body: some View {
        HStack(spacing: 12) {
            PlaylistArtworkView(tracks: tracks, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlaylistArtworkView: View {
    @EnvironmentObject private var library: LibraryStore
    let tracks: [Track]
    let size: CGFloat

    private var artworkTrack: Track? {
        tracks.first { library.artworkData(for: $0) != nil }
    }

    var body: some View {
        if let artworkTrack {
            ArtworkView(
                data: library.artworkData(for: artworkTrack),
                embedded: library.artworkIsEmbedded(for: artworkTrack),
                size: size
            )
        } else {
            PlaceholderArtwork(symbol: "music.note.list", size: size)
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var settings: AppSettings
    @State private var showingRename = false
    @State private var showingDeleteConfirmation = false
    @State private var renameText = ""
    let playlistID: UUID

    private var playlist: UserPlaylist? { library.playlist(id: playlistID) }
    private var tracks: [Track] { library.tracks(in: playlistID) }

    var body: some View {
        Group {
            if let playlist {
                List {
                    Section {
                        VStack(spacing: 10) {
                            PlaylistArtworkView(tracks: tracks, size: 116)
                            Text(playlist.name)
                                .font(.title2.bold())
                            Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                if let first = tracks.first {
                                    player.play(first, in: tracks)
                                }
                            } label: {
                                Label("Play Playlist", systemImage: "play.fill")
                                    .foregroundStyle(settings.contrastingAccentTextColor)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(settings.accentColor)
                            .disabled(tracks.isEmpty)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }

                    Section("Tracks") {
                        if tracks.isEmpty {
                            ContentUnavailableView(
                                "Playlist Is Empty",
                                systemImage: "music.note.list",
                                description: Text("Add tracks using the menu on a song, album, or Now Playing.")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(tracks) { track in
                                Button {
                                    player.play(track, in: tracks)
                                } label: {
                                    TrackListRow(
                                        track: track,
                                        showsArtwork: true,
                                        large: false,
                                        showsAlbum: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .trackLibraryActions(track)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        library.remove(track, from: playlistID)
                                    } label: {
                                        Label("Remove", systemImage: "minus.circle")
                                    }
                                }
                            }
                            .onMove { offsets, destination in
                                library.moveTracks(in: playlistID, from: offsets, to: destination)
                            }
                        }
                    }
                }
                .navigationTitle(playlist.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                renameText = playlist.name
                                showingRename = true
                            } label: {
                                Label("Rename Playlist", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        } label: {
                            Label("Playlist Actions", systemImage: "ellipsis.circle")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Playlist Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .alert("Rename Playlist", isPresented: $showingRename) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                library.renamePlaylist(playlistID, to: renameText)
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog(
            "Delete Playlist?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) {
                library.deletePlaylist(playlistID)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the playlist but does not delete any music files.")
        }
    }
}

struct PlaylistPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let tracks: [Track]

    private var itemDescription: String {
        tracks.count == 1 ? tracks[0].title : "\(tracks.count) tracks"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PlaylistCollectionView()
                    } label: {
                        Label("Add a Playlist", systemImage: "plus.circle.fill")
                    }
                }

                Section("Choose a Playlist") {
                    if library.playlists.isEmpty {
                        ContentUnavailableView(
                            "No Playlists Yet",
                            systemImage: "music.note.list",
                            description: Text("Tap Add a Playlist above, create one, then return here.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(library.playlists) { playlist in
                            Button {
                                _ = library.add(tracks, to: playlist.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    PlaylistArtworkView(tracks: library.tracks(in: playlist.id), size: 42)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                        Text("Add \(itemDescription)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct TrackLibraryActionsModifier: ViewModifier {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var showingPlaylistPicker = false
    @State private var showingMetadataEditor = false
    @State private var showingRemovalOptions = false
    let track: Track

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    player.playNext([track])
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                .tint(.indigo)
                Button {
                    player.addToQueue([track])
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
                .tint(.teal)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    showingMetadataEditor = true
                } label: {
                    Label("Edit Metadata", systemImage: "pencil")
                }
                .tint(.blue)
                Button {
                    showingPlaylistPicker = true
                } label: {
                    Label(
                        library.playlists.isEmpty ? "Add a Playlist" : "Add to Playlist",
                        systemImage: "text.badge.plus"
                    )
                }
                .tint(.purple)
            }
            .contextMenu {
                Button {
                    player.playNext([track])
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button {
                    player.addToQueue([track])
                } label: {
                    Label("Add to End of Queue", systemImage: "text.badge.plus")
                }
                Divider()
                Button {
                    library.toggleFavorite(track)
                } label: {
                    Label(
                        library.isFavorite(track) ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: library.isFavorite(track) ? "heart.slash" : "heart"
                    )
                }
                Button {
                    showingPlaylistPicker = true
                } label: {
                    Label(
                        library.playlists.isEmpty ? "Add a Playlist" : "Add to Playlist",
                        systemImage: "text.badge.plus"
                    )
                }
                Divider()
                Button {
                    showingMetadataEditor = true
                } label: {
                    Label("Edit Track Metadata", systemImage: "pencil")
                }
                Divider()
                Button {
                    showingRemovalOptions = true
                } label: {
                    Label("Remove or Delete Track", systemImage: "trash")
                }
            }
            .sheet(isPresented: $showingPlaylistPicker) {
                PlaylistPickerSheet(tracks: [track])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingMetadataEditor) {
                TrackMetadataEditorSheet(track: track)
            }
            .confirmationDialog(
                "Remove \(track.title)?",
                isPresented: $showingRemovalOptions,
                titleVisibility: .visible
            ) {
                Button("Remove from Library") {
                    Task { await library.removeTracks([track], deletingFiles: false) }
                }
                Button("Delete from iPhone", role: .destructive) {
                    Task { await library.removeTracks([track], deletingFiles: true) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Remove from Library keeps the audio file on your iPhone. Delete from iPhone permanently removes it.")
            }
    }
}

extension View {
    func trackLibraryActions(_ track: Track) -> some View {
        modifier(TrackLibraryActionsModifier(track: track))
    }
}


private struct MetadataTextField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
        }
        .padding(.vertical, 3)
    }
}

struct TrackMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let track: Track

    @State private var title: String
    @State private var artist: String
    @State private var albumArtist: String
    @State private var album: String
    @State private var trackNumber: String
    @State private var discNumber: String
    @State private var releaseYear: String
    @State private var artworkData: Data?
    @State private var replaceArtwork = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingArtworkSearch = false
    @State private var saveError: String?

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _albumArtist = State(initialValue: track.albumArtist)
        _album = State(initialValue: track.album)
        _trackNumber = State(initialValue: track.trackNumber > 0 ? String(track.trackNumber) : "")
        _discNumber = State(initialValue: String(max(1, track.discNumber)))
        _releaseYear = State(initialValue: track.releaseYear > 0 ? String(track.releaseYear) : "")
        _artworkData = State(initialValue: track.artworkData)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Track") {
                    MetadataTextField(label: "Title", prompt: "Enter track title", text: $title)
                    MetadataTextField(label: "Artist", prompt: "Enter performing artist", text: $artist)
                    MetadataTextField(label: "Album Artist", prompt: "Enter album artist", text: $albumArtist)
                    MetadataTextField(label: "Album", prompt: "Enter album title", text: $album)
                }

                Section("Position and Date") {
                    MetadataTextField(
                        label: "Track Number",
                        prompt: "Enter track number",
                        text: $trackNumber,
                        keyboardType: .numberPad
                    )
                    MetadataTextField(
                        label: "Disc Number",
                        prompt: "Enter disc number",
                        text: $discNumber,
                        keyboardType: .numberPad
                    )
                    MetadataTextField(
                        label: "Release Year",
                        prompt: "Enter release year",
                        text: $releaseYear,
                        keyboardType: .numberPad
                    )
                }

                Section("Artwork") {
                    HStack {
                        Spacer()
                        ArtworkView(
                            data: replaceArtwork ? artworkData : library.artworkData(for: track),
                            embedded: replaceArtwork ? false : library.artworkIsEmbedded(for: track),
                            size: 170
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Artwork from Photos", systemImage: "photo.badge.plus")
                    }

                    Button {
                        showingArtworkSearch = true
                    } label: {
                        Label("Search Online Artwork", systemImage: "globe")
                    }

                    Button(role: .destructive) {
                        artworkData = nil
                        replaceArtwork = true
                    } label: {
                        Label("Remove Artwork in Resonance", systemImage: "photo.badge.minus")
                    }

                    Text("For local FLAC and MP3 files, Save writes the edited tags and artwork directly into the audio file. Other formats are not directly writable yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if library.hasMetadataOverride(track) {
                    Section {
                        Button("Reset to File Metadata", role: .destructive) {
                            Task {
                                await library.resetMetadataOverrides(for: [track.id])
                                dismiss()
                            }
                        }
                    } footer: {
                        Text("This discards Resonance-only edits and rereads the original file tags.")
                    }
                }

                Section {
                    Text("Direct tag writing currently supports local FLAC and MP3 files. Resonance rereads the file after saving so the local library reflects the actual tags.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Track Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        library.updateTrackMetadataInBackground(
                            trackID: track.id,
                            title: title,
                            artist: artist,
                            albumArtist: albumArtist.isEmpty ? artist : albumArtist,
                            album: album,
                            trackNumber: Int(trackNumber) ?? 0,
                            discNumber: Int(discNumber) ?? 1,
                            releaseYear: Int(releaseYear) ?? 0,
                            artworkData: artworkData,
                            replaceArtwork: replaceArtwork
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          UIImage(data: data) != nil else { return }
                    artworkData = data
                    replaceArtwork = true
                }
            }
            .sheet(isPresented: $showingArtworkSearch) {
                OnlineArtworkSearchSheet(
                    artist: artist,
                    albumArtist: albumArtist,
                    album: album,
                    stagesSelection: true,
                    onApplyToApp: { data in
                        artworkData = data
                        replaceArtwork = true
                    },
                    onSaveToFiles: { data in
                        artworkData = data
                        replaceArtwork = true
                        return nil
                    }
                )
            }
            .alert("Could Not Save Metadata", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "The metadata could not be saved.")
            }
        }
    }
}

struct AlbumMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let album: Album

    @State private var albumTitle: String
    @State private var artist: String
    @State private var albumArtist: String
    @State private var releaseYear: String
    @State private var artworkData: Data?
    @State private var replaceArtwork = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingArtworkSearch = false
    @State private var saveError: String?

    init(album: Album) {
        self.album = album
        _albumTitle = State(initialValue: album.title)
        _artist = State(initialValue: album.tracks.first?.artist ?? album.artist)
        _albumArtist = State(initialValue: album.tracks.first?.albumArtist ?? album.artist)
        _releaseYear = State(initialValue: album.releaseYear > 0 ? String(album.releaseYear) : "")
        _artworkData = State(initialValue: album.artworkData)
    }

    private var canSave: Bool {
        !albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !albumArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Album") {
                    MetadataTextField(label: "Album Title", prompt: "Enter album title", text: $albumTitle)
                    MetadataTextField(label: "Artist", prompt: "Enter performing artist", text: $artist)
                    MetadataTextField(label: "Album Artist", prompt: "Enter album artist", text: $albumArtist)
                    MetadataTextField(
                        label: "Release Year",
                        prompt: "Enter release year",
                        text: $releaseYear,
                        keyboardType: .numberPad
                    )
                }

                Section("Artwork for Every Track") {
                    HStack {
                        Spacer()
                        ArtworkView(
                            data: replaceArtwork ? artworkData : album.artworkData,
                            embedded: replaceArtwork ? false : album.artworkIsEmbedded,
                            size: 190
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Artwork from Photos", systemImage: "photo.badge.plus")
                    }

                    Button {
                        showingArtworkSearch = true
                    } label: {
                        Label("Search Online Artwork", systemImage: "globe")
                    }

                    Button(role: .destructive) {
                        artworkData = nil
                        replaceArtwork = true
                    } label: {
                        Label("Remove Artwork in Resonance", systemImage: "photo.badge.minus")
                    }
                }

                Section(
                    content: {
                        ForEach(album.tracks.sorted { ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title) }) { track in
                            HStack(spacing: 12) {
                                Text(track.trackNumber > 0 ? String(track.trackNumber) : "—")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 28, alignment: .trailing)
                                Text(track.title)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Track \(track.trackNumber), \(track.title), read only")
                        }
                    },
                    header: {
                        Text("Track Titles and Numbers — Read Only")
                    },
                    footer: {
                        Text("Track title and track number are shown for reference and are not changed by an album-wide edit.")
                    }
                )

                Section {
                    Button("Reset Entire Album to File Metadata", role: .destructive) {
                        Task {
                            await library.resetMetadataOverrides(for: album.tracks.map(\.id))
                            dismiss()
                        }
                    }
                } footer: {
                    Text("Album edits apply to every track in this album, including both Artist and Album Artist.")
                }
            }
            .navigationTitle("Edit Album Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        library.updateAlbumMetadataInBackground(
                            trackIDs: album.tracks.map(\.id),
                            album: albumTitle,
                        artist: artist,
                        albumArtist: albumArtist,
                            releaseYear: Int(releaseYear) ?? 0,
                            artworkData: artworkData,
                            replaceArtwork: replaceArtwork
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          UIImage(data: data) != nil else { return }
                    artworkData = data
                    replaceArtwork = true
                }
            }
            .sheet(isPresented: $showingArtworkSearch) {
                OnlineArtworkSearchSheet(
                    artist: artist,
                    albumArtist: albumArtist,
                    album: albumTitle,
                    stagesSelection: true,
                    onApplyToApp: { data in
                        artworkData = data
                        replaceArtwork = true
                    },
                    onSaveToFiles: { data in
                        artworkData = data
                        replaceArtwork = true
                        return nil
                    }
                )
            }
            .alert("Could Not Save Metadata", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "The album metadata could not be saved.")
            }
        }
    }
}


struct ArtistMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let artist: Artist

    @State private var artistName: String
    @State private var albumArtistName: String
    @State private var artworkData: Data?
    @State private var replaceArtwork = false
    @State private var clearArtworkOverride = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingArtworkSearch = false
    @State private var saveError: String?

    init(artist: Artist) {
        self.artist = artist
        let firstTrack = artist.albums.flatMap(\.tracks).first
        _artistName = State(initialValue: firstTrack?.artist ?? artist.name)
        _albumArtistName = State(initialValue: firstTrack?.albumArtist ?? artist.name)
        _artworkData = State(initialValue: artist.artworkData)
    }

    private var inheritedArtworkData: Data? {
        artist.albums.compactMap(\.artworkData).first
    }

    private var inheritedArtworkIsEmbedded: Bool {
        artist.albums.first(where: { $0.artworkData != nil })?.artworkIsEmbedded ?? true
    }

    private var albumArtworkChoices: [Album] {
        artist.albums
            .filter { $0.artworkData != nil }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func isSelectedAlbumArtwork(_ album: Album) -> Bool {
        replaceArtwork && !clearArtworkOverride && artworkData == album.artworkData
    }

    private var previewArtworkData: Data? {
        if clearArtworkOverride { return inheritedArtworkData }
        if replaceArtwork { return artworkData }
        return artist.artworkData
    }

    private var previewArtworkIsEmbedded: Bool {
        if clearArtworkOverride { return inheritedArtworkIsEmbedded }
        if replaceArtwork { return false }
        return artist.artworkIsEmbedded
    }

    private var canSave: Bool {
        !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !albumArtistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        MetadataTextField(
                            label: "Artist Name",
                            prompt: "Enter artist name",
                            text: $artistName
                        )
                        MetadataTextField(
                            label: "Album Artist Name",
                            prompt: "Enter album artist name",
                            text: $albumArtistName
                        )
                    },
                    header: {
                        Text("Artist and Album Artist")
                    },
                    footer: {
                        Text("These names are written to every file represented by this artist entry.")
                    }
                )

                if !albumArtworkChoices.isEmpty {
                    Section(
                        content: {
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(albumArtworkChoices) { album in
                                        Button {
                                            artworkData = album.artworkData
                                            replaceArtwork = true
                                            clearArtworkOverride = false
                                        } label: {
                                            VStack(spacing: 6) {
                                                ArtworkView(
                                                    data: album.artworkData,
                                                    embedded: album.artworkIsEmbedded,
                                                    size: 96
                                                )
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 9)
                                                        .stroke(
                                                            isSelectedAlbumArtwork(album) ? Color.accentColor : Color.clear,
                                                            lineWidth: 3
                                                        )
                                                }
                                                .overlay(alignment: .topTrailing) {
                                                    if isSelectedAlbumArtwork(album) {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .symbolRenderingMode(.palette)
                                                            .foregroundStyle(.white, Color.accentColor)
                                                            .padding(5)
                                                    }
                                                }

                                                Text(album.title)
                                                    .font(.caption)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 100)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Use artwork from \(album.title)")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .scrollIndicators(.hidden)
                        },
                        header: {
                            Text("Choose from Album Covers")
                        },
                        footer: {
                            Text("Select any cover already available in this artist's collection. It will be used only for the artist display and will not change the album itself.")
                        }
                    )
                }

                Section("Artist Artwork") {
                    HStack {
                        Spacer()
                        ArtworkView(
                            data: previewArtworkData,
                            embedded: previewArtworkIsEmbedded,
                            size: 190,
                            showWarningBorder: false
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Artist Artwork from Photos", systemImage: "person.crop.square.badge.plus")
                    }

                    Button {
                        showingArtworkSearch = true
                    } label: {
                        Label("Search Online Artwork", systemImage: "globe")
                    }

                    Button(role: .destructive) {
                        artworkData = nil
                        replaceArtwork = true
                        clearArtworkOverride = false
                    } label: {
                        Label("Remove Artist Artwork", systemImage: "photo.badge.minus")
                    }

                    if artist.hasArtworkOverride {
                        Button {
                            clearArtworkOverride = true
                            replaceArtwork = false
                            artworkData = inheritedArtworkData
                        } label: {
                            Label("Use Album Artwork Again", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                }

                Section {
                    LabeledContent("Albums affected", value: String(artist.albums.count))
                    LabeledContent("Tracks affected", value: String(artist.albums.flatMap(\.tracks).count))
                } footer: {
                    Text("Changing either name updates every track represented by this artist entry. Album titles, release years, track titles, and track numbers remain unchanged.")
                }
            }
            .navigationTitle("Edit Artist Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        library.updateArtistMetadataInBackground(
                            artist: artist,
                            name: artistName,
                            albumArtist: albumArtistName,
                            artworkData: artworkData,
                            replaceArtwork: replaceArtwork,
                            clearArtworkOverride: clearArtworkOverride
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          UIImage(data: data) != nil else { return }
                    artworkData = data
                    replaceArtwork = true
                    clearArtworkOverride = false
                }
            }
            .sheet(isPresented: $showingArtworkSearch) {
                OnlineArtworkSearchSheet(
                    artist: artistName,
                    albumArtist: albumArtistName,
                    album: nil,
                    stagesSelection: true,
                    onApplyToApp: { data in
                        artworkData = data
                        replaceArtwork = true
                        clearArtworkOverride = false
                    },
                    onSaveToFiles: { data in
                        artworkData = data
                        replaceArtwork = true
                        clearArtworkOverride = false
                        return nil
                    }
                )
            }
            .alert("Could Not Save Metadata", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "The artist metadata could not be saved.")
            }
        }
    }
}
