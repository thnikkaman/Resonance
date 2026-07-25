import SwiftUI
import UIKit
import ImageIO

struct StreamingLibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @State private var showingOptions = false
    let openLibrary: () -> Void
    let openSettings: () -> Void

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
                Group {
                    switch remote.grouping {
                    case .artists:
                        RemoteArtistCollectionView(
                            artists: remote.artists(groupCompilationArtists: settings.groupCompilationArtists)
                        )
                    case .albumArtists:
                        RemoteArtistCollectionView(artists: remote.albumArtists)
                    case .albums:
                        RemoteAlbumCollectionView(albums: remote.albums)
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
                .safeAreaInset(edge: .top, spacing: 0) {
                    RemoteServerHeader(isExpanded: $settings.streamingConnectionInfoExpanded)
                }
                .searchable(text: $remote.searchText, prompt: "Search remote music")
                .refreshable { await remote.refresh(using: settings) }
            }
        }
        .navigationTitle("Streaming Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button(action: openLibrary) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Open local library")

                Button { showingOptions = true } label: {
                    Label("Library Options", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
                }

                NavigationLink {
                    RemotePlaylistCollectionView()
                } label: {
                    Label("Playlists", systemImage: "music.note.list")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .foregroundStyle(settings.contrastingAccentTextColor)
                        .background(settings.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(settings.streamBackend != .subsonic)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: openSettings) { Image(systemName: "server.rack") }
                Button {
                    Task { await remote.refresh(using: settings) }
                } label: {
                    Image(systemName: "arrow.clockwise")
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
        .onAppear {
            ResonanceDiagnostics.shared.record(
                "streaming.view.appeared",
                details: [
                    "grouping": remote.grouping.rawValue,
                    "connectionInfoExpanded": String(settings.streamingConnectionInfoExpanded)
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

private struct RemoteServerHeader: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: remote.isLoading ? "network.badge.shield.half.filled" : "externaldrive.connected.to.line.below")
                        .font(.title2)
                        .foregroundStyle(settings.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(remote.serverName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(remote.grouping.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(settings.accentColor)
                    }
                    Spacer()
                    if remote.isLoading { ProgressView() }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.streamBackend.shortName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(settings.accentColor)
                    Text(remote.connectionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(remote.catalogSyncStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let lastRefresh = remote.lastRefresh {
                        Text("Updated \(lastRefresh.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .tint(settings.accentColor)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .zIndex(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streaming connection information")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .onChange(of: isExpanded) { _, expanded in
            ResonanceDiagnostics.shared.record(
                "streaming.connectionInfo.changed",
                details: ["expanded": String(expanded)]
            )
        }
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
                    Text("Tracks from Various Artists albums appear under a single Various Artists entry.")
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
                ResonanceDiagnostics.shared.record(
                    "streaming.option.grouping.changed",
                    details: ["grouping": grouping.rawValue]
                )
            }
            .onChange(of: remote.sortDirection) { _, direction in
                ResonanceDiagnostics.shared.record(
                    "streaming.option.sort.changed",
                    details: ["direction": direction.rawValue]
                )
            }
            .onChange(of: settings.albumLayout) { _, layout in
                ResonanceDiagnostics.shared.record(
                    "streaming.option.layout.changed",
                    details: ["layout": layout.rawValue]
                )
            }
        }
    }
}

private struct RemoteArtistCollectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    let artists: [RemoteArtist]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    private var sections: [ArtistIndexSection<RemoteArtist>] {
        let uniqueArtists = Dictionary(grouping: artists) { resonanceNormalizedRemoteKey($0.name) }
            .compactMap { _, values in values.first }
        let grouped = Dictionary(grouping: uniqueArtists) { resonanceArtistIndexKey($0.name) }
        let order = resonanceArtistIndexOrder(
            for: Array(grouped.keys),
            ascending: remote.sortDirection == .ascending
        )
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
                items: remote.sortDirection == .ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.albumLayout == .grid ? 14 : 0) {
                        ForEach(sections, id: \.key) { section in
                            VStack(alignment: .leading, spacing: settings.albumLayout == .grid ? 8 : 0) {
                                Text(section.key)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, settings.albumLayout == .grid ? 0 : 7)
                                    .background(.background)

                                if settings.albumLayout == .grid {
                                    LazyVGrid(columns: columns, spacing: 18) {
                                        ForEach(section.items) { artist in
                                            NavigationLink {
                                                RemoteArtistDetailView(artist: artist)
                                            } label: {
                                                RemoteArtistTile(artist: artist)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    ForEach(section.items) { artist in
                                        NavigationLink {
                                            RemoteArtistDetailView(artist: artist)
                                        } label: {
                                            RemoteCollectionRow(
                                                title: artist.name,
                                                subtitle: "\(artist.albums.count) albums • \(artist.tracks.count) tracks",
                                                artworkURL: artist.artworkURL,
                                                artworkBase64: artist.artworkBase64,
                                                large: settings.albumLayout == .large
                                            )
                                            .padding(.vertical, settings.albumLayout == .compact ? 3 : 8)
                                        }
                                        .buttonStyle(.plain)
                                        Divider()
                                    }
                                }
                            }
                            .id("remote-artist-section-\(section.key)")
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 36)
                    .padding(.vertical)
                }

                if sections.count > 1 {
                    VerticalArtistIndex(
                        keys: sections.map(\.key),
                        diagnosticSurface: "streaming-artists"
                    ) { key in
                        ResonanceDiagnostics.shared.record(
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
        }
    }
}

private struct RemoteArtistTile: View {
    @EnvironmentObject private var settings: AppSettings
    let artist: RemoteArtist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteArtwork(
                url: artist.artworkURL,
                base64: artist.artworkBase64,
                size: settings.libraryThumbnailSize.gridArtworkPoints
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
    @EnvironmentObject private var remote: RemoteLibraryStore
    let albums: [RemoteAlbum]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    private var sections: [ArtistIndexSection<RemoteAlbum>] {
        let grouped = Dictionary(grouping: albums) { resonanceArtistIndexKey($0.title) }
        let order = resonanceArtistIndexOrder(
            for: Array(grouped.keys),
            ascending: remote.sortDirection == .ascending
        )
        return order.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            let sorted = values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
                items: remote.sortDirection == .ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.albumLayout == .grid ? 14 : 0) {
                        ForEach(sections, id: \.key) { section in
                            VStack(alignment: .leading, spacing: settings.albumLayout == .grid ? 8 : 0) {
                                Text(section.key)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, settings.albumLayout == .grid ? 0 : 7)
                                    .background(.background)

                                if settings.albumLayout == .grid {
                                    LazyVGrid(columns: columns, spacing: 18) {
                                        ForEach(section.items) { album in
                                            NavigationLink {
                                                RemoteAlbumDetailView(album: album)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    RemoteArtwork(
                                                        url: album.artworkURL,
                                                        base64: album.artworkBase64,
                                                        size: settings.libraryThumbnailSize.gridArtworkPoints
                                                    )
                                                    Text(album.title)
                                                        .font(settings.libraryTextSize.font.weight(.semibold))
                                                        .lineLimit(1)
                                                    Text(album.artist)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    ForEach(section.items) { album in
                                        NavigationLink {
                                            RemoteAlbumDetailView(album: album)
                                        } label: {
                                            RemoteCollectionRow(
                                                title: album.title,
                                                subtitle: album.releaseYear > 0 ? "\(album.artist) • \(album.releaseYear)" : album.artist,
                                                artworkURL: album.artworkURL,
                                                artworkBase64: album.artworkBase64,
                                                large: settings.albumLayout == .large
                                            )
                                            .padding(.vertical, settings.albumLayout == .compact ? 2 : 8)
                                        }
                                        .buttonStyle(.plain)
                                        Divider()
                                    }
                                }
                            }
                            .id("remote-album-section-\(section.key)")
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 36)
                    .padding(.vertical)
                }

                if sections.count > 1 {
                    VerticalArtistIndex(
                        keys: sections.map(\.key),
                        diagnosticSurface: "streaming-albums"
                    ) { key in
                        ResonanceDiagnostics.shared.record(
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
        }
    }
}

private struct RemoteTrackCollectionView: View {
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var settings: AppSettings
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
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
        }
    }
}

private struct RemoteArtistDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
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

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RemoteArtwork(url: artist.artworkURL, base64: artist.artworkBase64, size: 82)
                VStack(alignment: .leading, spacing: 6) {
                    Text(artist.name).font(.title2.bold())
                    Text("\(artist.albums.count) albums • \(artist.tracks.count) tracks")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            Task { await remote.playArtist(artist, using: player) }
                        } label: {
                            Label("Play Artist", systemImage: "play.fill")
                                .foregroundStyle(settings.contrastingAccentTextColor)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.accentColor)

                        Button {
                            Task { await remote.playArtist(artist, using: player, shuffle: true) }
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Spacer()
            }
            .padding()

            VStack(spacing: 10) {
                Picker("Album sort", selection: $settings.artistAlbumSort) {
                    ForEach(ArtistAlbumSort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Album view", selection: $settings.artistAlbumLayout) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(ArtistAlbumLayout.grid)
                    Label("List", systemImage: "list.bullet").tag(ArtistAlbumLayout.list)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            if settings.artistAlbumLayout == .grid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        NavigationLink {
                            RemoteAllAlbumsTrackListView(artistName: artist.name, tracks: allTracks)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    RemoteArtwork(
                                        url: artist.artworkURL,
                                        base64: artist.artworkBase64,
                                        size: settings.libraryThumbnailSize.gridArtworkPoints
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

                        ForEach(sortedAlbums) { album in
                            NavigationLink {
                                RemoteAlbumDetailView(album: album)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    RemoteArtwork(
                                        url: album.artworkURL,
                                        base64: album.artworkBase64,
                                        size: settings.libraryThumbnailSize.gridArtworkPoints
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
                        }
                    }
                    .padding()
                }
            } else {
                List {
                    NavigationLink {
                        RemoteAllAlbumsTrackListView(artistName: artist.name, tracks: allTracks)
                    } label: {
                        RemoteCollectionRow(
                            title: "All Albums",
                            subtitle: "\(allTracks.count) tracks, grouped by album",
                            artworkURL: artist.artworkURL,
                            artworkBase64: artist.artworkBase64,
                            large: false
                        )
                    }
                    ForEach(sortedAlbums) { album in
                        NavigationLink {
                            RemoteAlbumDetailView(album: album)
                        } label: {
                            RemoteCollectionRow(
                                title: album.title,
                                subtitle: album.releaseYear > 0 ? String(album.releaseYear) : "Release date unavailable",
                                artworkURL: album.artworkURL,
                                artworkBase64: album.artworkBase64,
                                large: false
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RemoteAllAlbumsTrackListView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
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
            }

            Section("Tracks") {
                ForEach(tracks) { track in
                    Button {
                        Task { await remote.play(track, in: tracks, using: player) }
                    } label: {
                        RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { Task { await remote.playNext([track], using: player) } } label: {
                            Label("Play Next", systemImage: "text.insert")
                        }
                        Button { Task { await remote.addToQueue([track], using: player) } } label: {
                            Label("Add to End of Queue", systemImage: "text.append")
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
        }
        .navigationTitle("\(artistName) — All Albums")
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RemoteAlbumDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var playlistItems: [RemoteTrackItem] = []
    @State private var showingPlaylistPicker = false
    let album: RemoteAlbum

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    RemoteArtwork(url: album.artworkURL, base64: album.artworkBase64, size: 118)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(album.title).font(.title2.bold())
                        Text(album.artist).foregroundStyle(.secondary)
                        if album.releaseYear > 0 { Text(String(album.releaseYear)).foregroundStyle(.secondary) }
                        Button {
                            Task { await remote.playAlbum(album, using: player) }
                        } label: {
                            Label("Play Album", systemImage: "play.fill")
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
                ForEach(album.tracks) { track in
                    Button {
                        Task { await remote.play(track, in: album.tracks, using: player) }
                    } label: {
                        RemoteTrackRow(track: track, isPlaying: player.currentTrack?.id == track.id)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { Task { await remote.playNext([track], using: player) } } label: {
                            Label("Play Next", systemImage: "text.insert")
                        }
                        Button { Task { await remote.addToQueue([track], using: player) } } label: {
                            Label("Add to End of Queue", systemImage: "text.append")
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
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await remote.playNext(album.tracks, using: player) }
                    } label: {
                        Label("Play Album Next", systemImage: "text.insert")
                    }
                    Button {
                        Task { await remote.addToQueue(album.tracks, using: player) }
                    } label: {
                        Label("Add Album to End of Queue", systemImage: "text.append")
                    }
                    if settings.streamBackend == .subsonic {
                        Button {
                            playlistItems = album.tracks
                            showingPlaylistPicker = true
                        } label: {
                            Label("Add Album to Server Playlist", systemImage: "music.note.list")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            RemotePlaylistPickerSheet(items: playlistItems)
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
                                artworkURL: playlist.artworkURL,
                                artworkBase64: playlist.artworkBase64,
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
                            RemoteArtwork(url: playlist.artworkURL, base64: playlist.artworkBase64, size: 116)
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                                    artworkURL: playlist.artworkURL,
                                    artworkBase64: playlist.artworkBase64,
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
    let artworkURL: URL?
    let artworkBase64: String?
    let large: Bool

    var body: some View {
        HStack(spacing: large ? 12 : 8) {
            RemoteArtwork(
                url: artworkURL,
                base64: artworkBase64,
                size: large ? max(76, settings.libraryThumbnailSize.points * 2) : settings.libraryThumbnailSize.points
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
            RemoteArtwork(url: track.artworkURL, base64: track.artworkBase64, size: 42)
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

    init() {
        thumbnails.countLimit = 600
        thumbnails.totalCostLimit = 96 * 1024 * 1024
    }

    func image(
        url: URL?,
        base64: String?,
        sourceKey: String,
        maxPixelSize: Int
    ) async -> RemoteArtworkImageBox? {
        let boundedPixelSize = min(1536, max(96, maxPixelSize))
        let thumbnailKey = "\(sourceKey)|\(boundedPixelSize)" as NSString
        if let cached = thumbnails.object(forKey: thumbnailKey) { return cached }

        let data: Data
        if let base64 {
            guard let decoded = Data(base64Encoded: base64) else { return nil }
            data = decoded
        } else if let url {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 20
                let (downloaded, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { return nil }
                data = downloaded
            } catch {
                return nil
            }
        } else {
            return nil
        }

        let box = await Task.detached(priority: .utility) {
            Self.downsample(data: data, maxPixelSize: boundedPixelSize)
        }.value
        guard let box else { return nil }
        let cost = max(1, box.image.bytesPerRow * box.image.height)
        thumbnails.setObject(box, forKey: thumbnailKey, cost: cost)
        return box
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

private struct RemoteArtwork: View {
    @Environment(\.displayScale) private var displayScale

    let url: URL?
    let base64: String?
    let size: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    private var sourceKey: String {
        if let url { return url.absoluteString }
        if let base64 {
            // Embedded artwork is rare for the remote backend. The prefix plus
            // the stable String hash avoids retaining the complete image text
            // as an image-cache key.
            return "base64:\(base64.prefix(32)):\(base64.hashValue)"
        }
        return "placeholder"
    }

    private var taskKey: String {
        "\(sourceKey)|\(Int((size * displayScale).rounded(.up)))"
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
        .task(id: taskKey) { await loadArtwork() }
    }

    @MainActor
    private func loadArtwork() async {
        guard url != nil || base64 != nil else {
            image = nil
            didFail = false
            return
        }

        isLoading = true
        didFail = false
        defer { isLoading = false }

        let pixels = Int((size * displayScale).rounded(.up))
        let loaded = await RemoteArtworkLoader.shared.image(
            url: url,
            base64: base64,
            sourceKey: sourceKey,
            maxPixelSize: pixels
        )
        guard !Task.isCancelled else { return }
        if let loaded {
            image = UIImage(cgImage: loaded.image, scale: displayScale, orientation: .up)
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

private func formatDuration(_ duration: Double) -> String {
    guard duration.isFinite, duration > 0 else { return "—:—" }
    let seconds = Int(duration.rounded())
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
