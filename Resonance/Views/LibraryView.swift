import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings
    @State private var importing = false
    @State private var showingLibraryOptions = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if library.isScanning && library.tracks.isEmpty {
                    ProgressView("Indexing music…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch library.grouping {
                    case .artists:
                        ArtistCollectionView(artists: library.artists)
                    case .albumArtists:
                        ArtistCollectionView(artists: library.albumArtists)
                    case .albums:
                        AlbumCollectionView(albums: library.albums)
                    case .songs:
                        TrackCollectionView(tracks: library.filteredTracks)
                    case .favorites:
                        SmartTrackCollectionView(
                            title: "Favorites",
                            tracks: library.favoriteTracks,
                            systemImage: "heart.fill",
                            emptyDescription: "Favorite tracks from a song menu or the Now Playing screen."
                        )
                    case .recentlyAdded:
                        SmartTrackCollectionView(
                            title: "Recently Added",
                            tracks: library.recentlyAddedTracks,
                            systemImage: "clock.badge.plus",
                            emptyDescription: "Newly imported tracks will appear here."
                        )
                    case .recentlyPlayed:
                        SmartTrackCollectionView(
                            title: "Recently Played",
                            tracks: library.recentlyPlayedTracks,
                            systemImage: "clock.arrow.circlepath",
                            emptyDescription: "Tracks appear here after playback begins."
                        )
                    }
                }
            }
        }
        .navigationTitle(library.grouping == .artists ? "Library" : library.grouping.rawValue)
        .searchable(text: $library.searchText)
        .background {
            ResonanceThemeBackdrop()
        }
        .resonanceTabBottomSpace()
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
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

            ToolbarItemGroup(placement: .topBarTrailing) {
                ResonanceToolbarIconButton(
                    accessibilityLabel: "Scan Resonance Music folder",
                    systemImage: "arrow.clockwise"
                ) {
                    Task { await library.scanSharedMusicFolder(forceMetadataRefresh: true) }
                }
                .disabled(library.isScanning)

                ResonanceToolbarIconButton(
                    accessibilityLabel: "Add music to library",
                    systemImage: "plus"
                ) {
                    importing = true
                }
            }
        }
        .sheet(isPresented: $showingLibraryOptions) {
            LibraryOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.audio, .folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await library.importURLs(urls) }
            }
        }
    }
}

private struct LibraryOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Browse Library By") {
                    Picker("Library grouping", selection: $library.grouping) {
                        ForEach(LibraryGrouping.allCases) { grouping in
                            Text(grouping.rawValue).tag(grouping)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Sort Order") {
                    Picker("Sort direction", selection: $library.sortDirection) {
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
                    Picker("Library view style", selection: $settings.albumLayout) {
                        ForEach(AlbumLayout.allCases) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("View Options") {
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
            .navigationTitle("Library Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ArtistIndexSection<Item: Identifiable> {
    let key: String
    let items: [Item]
}

func resonanceArtistIndexKey(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return "#" }
    let folded = String(first).folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: .current
    ).uppercased()
    guard let character = folded.first else { return "#" }
    if character.isNumber { return "0–9" }
    if character >= "A" && character <= "Z" { return String(character) }
    if first.isLetter { return String(first) }
    return "#"
}

func resonanceArtistIndexOrder(for keys: [String], ascending: Bool) -> [String] {
    let romanKeys = Set(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init))
    let present = Set(keys)
    var order: [String] = []

    if present.contains("0–9") { order.append("0–9") }
    order.append(contentsOf: romanKeys.sorted().filter { present.contains($0) })

    let otherTextKeys = present
        .subtracting(romanKeys)
        .subtracting(["0–9", "#"])
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    order.append(contentsOf: otherTextKeys)

    if present.contains("#") { order.append("#") }
    return ascending ? order : Array(order.reversed())
}

struct VerticalArtistIndex: View {
    let keys: [String]
    let diagnosticSurface: String
    let onSelect: (String) -> Void

    init(
        keys: [String],
        diagnosticSurface: String = "artists",
        onSelect: @escaping (String) -> Void
    ) {
        self.keys = keys
        self.diagnosticSurface = diagnosticSurface
        self.onSelect = onSelect
    }

    @State private var selectedKey: String?
    @State private var selectedRow = 0
    @State private var gestureKey: String?
    @State private var gestureStarted = false
    @State private var hideTask: Task<Void, Never>?

    private let indexColumnWidth: CGFloat = 32
    private let bubbleSize: CGFloat = 58
    private let verticalInset: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(1, geometry.size.height - verticalInset * 2)
            let rowHeight = min(18, max(9, floor(availableHeight / CGFloat(max(keys.count, 1)))))
            let indexHeight = rowHeight * CGFloat(keys.count)
            let topInset = max(verticalInset, (geometry.size.height - indexHeight) / 2)

            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: rowHeight < 11 ? 8 : 10, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.tint)
                            .frame(width: indexColumnWidth, height: rowHeight)
                    }
                }
                .offset(y: topInset)
                .allowsHitTesting(false)

                if let selectedKey {
                    Text(selectedKey)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: bubbleSize, height: bubbleSize)
                        .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 16))
                        .offset(
                            x: -(indexColumnWidth + 10),
                            y: topInset + CGFloat(selectedRow) * rowHeight + (rowHeight - bubbleSize) / 2
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .contentShape(Rectangle())
            // Hit-test in the full-height index container. The previous build
            // attached the gesture to a positioned VStack, which made y values
            // dependent on the transformed child coordinate space. A high
            // priority gesture keeps the system scroll indicator from claiming
            // touches in this strip.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !gestureStarted {
                            gestureStarted = true
                            ResonanceDiagnostics.shared.recordDeferred(
                                "alphabet.gesture.begin",
                                details: ["surface": diagnosticSurface]
                            )
                        }
                        selectRow(
                            at: value.location.y,
                            topInset: topInset,
                            rowHeight: rowHeight
                        )
                    }
                    .onEnded { _ in
                        ResonanceDiagnostics.shared.recordDeferred(
                            "alphabet.gesture.end",
                            details: [
                                "surface": diagnosticSurface,
                                "selected": selectedKey ?? "none"
                            ]
                        )
                        gestureStarted = false
                        gestureKey = nil
                        scheduleBubbleHide()
                    }
            )
        }
        .frame(width: indexColumnWidth)
        .frame(maxHeight: .infinity)
        .accessibilityLabel("Alphabet index")
    }

    private func selectRow(at y: CGFloat, topInset: CGFloat, rowHeight: CGFloat) {
        guard !keys.isEmpty else { return }
        hideTask?.cancel()
        let relativeY = min(
            max(0, y - topInset),
            max(0, rowHeight * CGFloat(keys.count) - 0.001)
        )
        let index = min(keys.count - 1, max(0, Int(floor(relativeY / max(1, rowHeight)))))
        let key = keys[index]
        selectedRow = index
        selectedKey = key
        if gestureKey != key {
            gestureKey = key
            ResonanceDiagnostics.shared.recordDeferred(
                "alphabet.selection",
                details: [
                    "surface": diagnosticSurface,
                    "key": key,
                    "index": String(index)
                ]
            )
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(key)
        }
    }

    private func scheduleBubbleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { selectedKey = nil }
        }
    }
}

struct ArtistCollectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @State private var artistToRemove: Artist?
    @State private var artistToEdit: Artist?
    let artists: [Artist]

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    private var indexedSections: [ArtistIndexSection<Artist>] {
        let grouped = Dictionary(grouping: artists) { resonanceArtistIndexKey($0.name) }
        let preferredOrder = resonanceArtistIndexOrder(
            for: Array(grouped.keys),
            ascending: library.sortDirection == .ascending
        )
        return preferredOrder.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            let sorted = values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
                items: library.sortDirection == .ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                Group {
                    switch settings.albumLayout {
                    case .grid:
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(indexedSections, id: \.key) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(section.key)
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                        LazyVGrid(columns: gridColumns, spacing: 18) {
                                            ForEach(section.items) { artist in
                                                NavigationLink(value: artist) {
                                                    ArtistTile(artist: artist)
                                                }
                                                .buttonStyle(.plain)
                                                .contextMenu {
                                                    Button { artistToEdit = artist } label: {
                                                        Label("Edit Artist Metadata", systemImage: "pencil")
                                                    }
                                                    Button(role: .destructive) { artistToRemove = artist } label: {
                                                        Label("Remove Artist from Library", systemImage: "trash")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .id("artist-section-\(section.key)")
                                }
                            }
                            .padding(.leading)
                            .padding(.trailing, 40)
                            .padding(.vertical)
                        }

                    case .compact, .large:
                        List {
                            ForEach(indexedSections, id: \.key) { section in
                                Section {
                                    ForEach(section.items) { artist in
                                        NavigationLink(value: artist) {
                                            ArtistListRow(artist: artist, large: settings.albumLayout == .large)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) { artistToRemove = artist } label: {
                                                Label("Remove Artist", systemImage: "trash")
                                            }
                                            Button { artistToEdit = artist } label: {
                                                Label("Edit Artist", systemImage: "pencil")
                                            }
                                            .tint(.accentColor)
                                        }
                                        .contextMenu {
                                            Button { artistToEdit = artist } label: {
                                                Label("Edit Artist Metadata", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) { artistToRemove = artist } label: {
                                                Label("Remove Artist from Library", systemImage: "trash")
                                            }
                                        }
                                        .listRowInsets(
                                            EdgeInsets(
                                                top: settings.albumLayout == .compact ? 2 : 8,
                                                leading: 16,
                                                bottom: settings.albumLayout == .compact ? 2 : 8,
                                                trailing: 40
                                            )
                                        )
                                    }
                                } header: {
                                    Text(section.key)
                                }
                                .id("artist-section-\(section.key)")
                            }
                        }
                    }
                }

                if indexedSections.count > 1 {
                    VerticalArtistIndex(keys: indexedSections.map(\.key)) { key in
                        proxy.scrollTo("artist-section-\(key)", anchor: .top)
                    }
                    .padding(.trailing, 1)
                    .padding(.vertical, 4)
                }
            }
        }
        .alert(
            "Remove artist?",
            isPresented: Binding(
                get: { artistToRemove != nil },
                set: { if !$0 { artistToRemove = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { artistToRemove = nil }
            Button("Remove from Library") {
                if let artist = artistToRemove {
                    Task { await library.removeArtist(artist, deletingFiles: false) }
                }
                artistToRemove = nil
            }
            Button("Delete from iPhone", role: .destructive) {
                if let artist = artistToRemove {
                    Task { await library.removeArtist(artist, deletingFiles: true) }
                }
                artistToRemove = nil
            }
        } message: {
            Text("Remove from Library keeps the audio files on your iPhone but hides them from Resonance. Delete from iPhone removes the files permanently.")
        }
        .sheet(item: $artistToEdit) { artist in
            ArtistMetadataEditorSheet(artist: artist)
        }
        .navigationDestination(for: Artist.self) { artist in
            ArtistDetailView(artist: artist)
        }
    }
}

private struct ArtistTile: View {
    @EnvironmentObject private var settings: AppSettings
    let artist: Artist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(
                data: artist.artworkData,
                embedded: artist.artworkIsEmbedded,
                size: settings.libraryThumbnailSize.gridArtworkPoints,
                showWarningBorder: false
            )
            .frame(maxWidth: .infinity)

            HStack(spacing: 5) {
                ScrollableArtistName(
                    artist.name,
                    font: settings.libraryTextSize.font.weight(.semibold)
                )
                if artist.hasMetadataOverride {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
            Text("\(artist.albums.count) album\(artist.albums.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct ArtistListRow: View {
    @EnvironmentObject private var settings: AppSettings
    let artist: Artist
    let large: Bool

    var body: some View {
        HStack(spacing: large ? 12 : 7) {
            ArtworkView(
                data: artist.artworkData,
                embedded: artist.artworkIsEmbedded,
                size: large ? max(76, settings.libraryThumbnailSize.points * 2) : settings.libraryThumbnailSize.points,
                showWarningBorder: false
            )
            VStack(alignment: .leading, spacing: large ? 4 : 1) {
                HStack(spacing: 5) {
                    ScrollableArtistName(
                        artist.name,
                        font: settings.libraryTextSize.font.weight(.semibold)
                    )
                    if artist.hasMetadataOverride {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
                Text("\(artist.albums.count) album\(artist.albums.count == 1 ? "" : "s")")
                    .font(large ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ScrollableArtistName: View {
    let name: String
    let font: Font

    init(_ name: String, font: Font) {
        self.name = name
        self.font = font
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(name)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollIndicators(.hidden)
        .accessibilityLabel(name)
    }
}

struct ArtistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var artistToEdit: Artist?
    @State private var albumToEdit: Album?
    @State private var albumToRemove: Album?
    let artist: Artist

    private var liveArtist: Artist { library.refreshedArtist(artist) }

    private var sortedAlbums: [Album] {
        switch settings.artistAlbumSort {
        case .title:
            return liveArtist.albums.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .newest:
            return liveArtist.albums.sorted {
                if $0.releaseYear == $1.releaseYear {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.releaseYear > $1.releaseYear
            }
        case .oldest:
            return liveArtist.albums.sorted {
                if $0.releaseYear == $1.releaseYear {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                if $0.releaseYear == 0 { return false }
                if $1.releaseYear == 0 { return true }
                return $0.releaseYear < $1.releaseYear
            }
        }
    }

    private var allTracks: [Track] {
        liveArtist.albums.flatMap(\.tracks).sorted { lhs, rhs in
            let albumComparison = lhs.album.localizedStandardCompare(rhs.album)
            if albumComparison != .orderedSame { return albumComparison == .orderedAscending }
            if lhs.trackNumber != rhs.trackNumber { return lhs.trackNumber < rhs.trackNumber }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 10) {
                        ResonanceHeroActionButton(title: "Play", systemImage: "play.fill", tint: settings.accentColor, prominent: true) {
                            if let first = allTracks.first { player.play(first, in: allTracks) }
                        }
                        ResonanceHeroActionButton(title: "Shuffle", systemImage: "shuffle", tint: settings.accentColor, prominent: false) {
                            player.shuffleAndPlay(allTracks)
                        }
                    }

                    ArtworkView(
                        data: liveArtist.artworkData,
                        embedded: liveArtist.artworkIsEmbedded,
                        size: 158,
                        showWarningBorder: false
                    )

                    VStack(spacing: 10) {
                        ResonanceHeroActionButton(title: "Edit", systemImage: "pencil", tint: settings.accentColor, prominent: false) {
                            artistToEdit = liveArtist
                        }
                        ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                            player.addToQueue(allTracks)
                        }
                    }
                }
                .disabled(allTracks.isEmpty)

                HStack(spacing: 5) {
                    ScrollableArtistName(liveArtist.name, font: .title3.bold())
                    if liveArtist.hasMetadataOverride {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                    }
                }
                Text("(liveArtist.albums.count) albums • (allTracks.count) tracks")
                    .font(.caption)
                    .foregroundStyle(settings.themeSecondaryColor)
            }
            .contentShape(Rectangle())
            .resonanceHeroSurface()
            .resonanceTopDownDismiss { dismiss() }
            .contextMenu {
                Button { artistToEdit = liveArtist } label: {
                    Label("Edit Artist Metadata", systemImage: "pencil")
                }
                Divider()
                Button {
                    if let first = allTracks.first { player.play(first, in: allTracks) }
                } label: {
                    Label("Play Artist", systemImage: "play.fill")
                }
                Button {
                    player.shuffleAndPlay(allTracks)
                } label: {
                    Label("Shuffle Artist", systemImage: "shuffle")
                }
            }

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
            .background {
                ResonanceThemeSurfaceBackdrop()
            }
            .resonanceTopDownDismiss { dismiss() }

            if settings.artistAlbumLayout == .grid {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 18) {
                        NavigationLink {
                            AllAlbumsTrackListView(artistName: liveArtist.name, tracks: allTracks)
                        } label: {
                            AllAlbumsTile(artist: liveArtist)
                        }
                        .buttonStyle(.plain)

                        ForEach(sortedAlbums) { album in
                            NavigationLink(value: album) {
                                AlbumTile(album: album)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { albumToEdit = album } label: {
                                    Label("Edit Album Metadata", systemImage: "pencil")
                                }
                                Divider()
                                Button { albumToRemove = album } label: {
                                    Label("Remove or Delete Album", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background {
                    ResonanceThemeSurfaceBackdrop()
                }
            } else {
                List {
                    NavigationLink {
                        AllAlbumsTrackListView(artistName: liveArtist.name, tracks: allTracks)
                    } label: {
                        HStack(spacing: 12) {
                            PlaceholderArtwork(symbol: "square.stack.3d.up.fill", size: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("All Albums").font(.headline)
                                Text("\(allTracks.count) tracks, grouped by album")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(sortedAlbums) { album in
                        NavigationLink(value: album) {
                            HStack(spacing: 12) {
                                ArtworkView(
                                    data: album.artworkData,
                                    embedded: album.artworkIsEmbedded,
                                    size: 58
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(album.title).font(settings.libraryTextSize.font.weight(.semibold)).lineLimit(1)
                                    Text(album.yearLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button { albumToEdit = album } label: {
                                Label("Edit Album Metadata", systemImage: "pencil")
                            }
                            Divider()
                            Button { albumToRemove = album } label: {
                                Label("Remove or Delete Album", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background {
                    ResonanceThemeSurfaceBackdrop()
                }
            }
        }
        .navigationTitle(liveArtist.name)
        .resonanceDetailBottomSpace()
        .sheet(item: $artistToEdit) { artist in
            ArtistMetadataEditorSheet(artist: artist)
        }
        .sheet(item: $albumToEdit) { album in
            AlbumMetadataEditorSheet(album: album)
        }
        .confirmationDialog(
            "Remove \(albumToRemove?.title ?? "album")?",
            isPresented: Binding(
                get: { albumToRemove != nil },
                set: { if !$0 { albumToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove from Library") {
                if let albumToRemove {
                    Task { await library.removeTracks(albumToRemove.tracks, deletingFiles: false) }
                }
                albumToRemove = nil
            }
            Button("Delete from iPhone", role: .destructive) {
                if let albumToRemove {
                    Task { await library.removeTracks(albumToRemove.tracks, deletingFiles: true) }
                }
                albumToRemove = nil
            }
            Button("Cancel", role: .cancel) { albumToRemove = nil }
        } message: {
            Text("Remove from Library keeps the audio files on your iPhone. Delete from iPhone permanently removes them.")
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
    }
}

private struct AllAlbumsTile: View {
    @EnvironmentObject private var settings: AppSettings
    let artist: Artist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                ArtworkView(
                    data: artist.artworkData,
                    embedded: artist.artworkIsEmbedded,
                    size: settings.libraryThumbnailSize.gridArtworkPoints,
                    showWarningBorder: false
                )
                Color.black.opacity(0.28)
                    .frame(
                        width: settings.libraryThumbnailSize.gridArtworkPoints,
                        height: settings.libraryThumbnailSize.gridArtworkPoints
                    )
                    .clipShape(RoundedRectangle(cornerRadius: max(8, settings.libraryThumbnailSize.gridArtworkPoints * 0.08)))
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            Text("All Albums")
                .font(settings.libraryTextSize.font.weight(.semibold))
                .lineLimit(1)
            Text("\(artist.albums.flatMap(\.tracks).count) tracks")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct AlbumCollectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @State private var albumToEdit: Album?
    @State private var albumToRemove: Album?
    let albums: [Album]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    var body: some View {
        Group {
            if settings.albumLayout == .grid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                AlbumTile(album: album)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { albumToEdit = album } label: {
                                    Label("Edit Album Metadata", systemImage: "pencil")
                                }
                                Divider()
                                Button { albumToRemove = album } label: {
                                    Label("Remove or Delete Album", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                List(albums) { album in
                    NavigationLink(value: album) {
                        if settings.albumLayout == .compact {
                            HStack(spacing: 7) {
                                ArtworkView(
                                    data: album.artworkData,
                                    embedded: album.artworkIsEmbedded,
                                    size: settings.libraryThumbnailSize.points
                                )
                                Text(album.title)
                                    .font(settings.libraryTextSize.font.weight(.medium))
                                    .lineLimit(1)
                                Text("— \(album.artist)")
                                    .font(settings.libraryTextSize.font)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 0)
                        } else {
                            HStack(spacing: 12) {
                                ArtworkView(
                                    data: album.artworkData,
                                    embedded: album.artworkIsEmbedded,
                                    size: max(76, settings.libraryThumbnailSize.points * 2)
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(album.title).font(settings.libraryTextSize.font.weight(.semibold))
                                    Text(album.artist).foregroundStyle(.secondary)
                                    Text(album.yearLabel).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .contextMenu {
                        Button { albumToEdit = album } label: {
                            Label("Edit Album Metadata", systemImage: "pencil")
                        }
                        Divider()
                        Button { albumToRemove = album } label: {
                            Label("Remove or Delete Album", systemImage: "trash")
                        }
                    }
                    .listRowInsets(
                        EdgeInsets(
                            top: settings.albumLayout == .compact ? 2 : 8,
                            leading: 16,
                            bottom: settings.albumLayout == .compact ? 2 : 8,
                            trailing: 16
                        )
                    )
                }
            }
        }
        .sheet(item: $albumToEdit) { album in
            AlbumMetadataEditorSheet(album: album)
        }
        .confirmationDialog(
            "Remove \(albumToRemove?.title ?? "album")?",
            isPresented: Binding(
                get: { albumToRemove != nil },
                set: { if !$0 { albumToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove from Library") {
                if let albumToRemove {
                    Task { await library.removeTracks(albumToRemove.tracks, deletingFiles: false) }
                }
                albumToRemove = nil
            }
            Button("Delete from iPhone", role: .destructive) {
                if let albumToRemove {
                    Task { await library.removeTracks(albumToRemove.tracks, deletingFiles: true) }
                }
                albumToRemove = nil
            }
            Button("Cancel", role: .cancel) { albumToRemove = nil }
        } message: {
            Text("Remove from Library keeps the audio files on your iPhone. Delete from iPhone permanently removes them.")
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
    }
}

struct AlbumTile: View {
    @EnvironmentObject private var settings: AppSettings
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(
                data: album.artworkData,
                embedded: album.artworkIsEmbedded,
                size: settings.libraryThumbnailSize.gridArtworkPoints
            )
            .frame(maxWidth: .infinity)
            Text(album.title)
                .font(settings.libraryTextSize.font.weight(.semibold))
                .lineLimit(1)
            Text(album.releaseYear > 0 ? "\(album.artist) • \(album.releaseYear)" : album.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct TrackCollectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var player: PlayerController
    let tracks: [Track]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: max(2, settings.libraryThumbnailSize.gridColumnCount - 1)
        )
    }

    var body: some View {
        Group {
            if settings.albumLayout == .grid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(tracks) { track in
                            Button { player.play(track, in: tracks) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ArtworkView(
                                        data: track.artworkData,
                                        embedded: track.artworkIsEmbedded,
                                        size: settings.libraryThumbnailSize.gridArtworkPoints
                                    )
                                    HStack(spacing: 5) {
                                        PlayingTrackVisualizer(track: track)
                                        Text(track.title)
                                            .font(settings.libraryTextSize.font.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    Text("\(track.artist) — \(track.album)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .trackLibraryActions(track)
                        }
                    }
                    .padding()
                }
            } else {
                List(tracks) { track in
                    Button { player.play(track, in: tracks) } label: {
                        TrackListRow(
                            track: track,
                            showsArtwork: true,
                            large: settings.albumLayout == .large,
                            showsAlbum: true
                        )
                    }
                    .buttonStyle(.plain)
                    .trackLibraryActions(track)
                    .listRowInsets(
                        EdgeInsets(
                            top: settings.albumLayout == .compact ? 2 : 7,
                            leading: 16,
                            bottom: settings.albumLayout == .compact ? 2 : 7,
                            trailing: 16
                        )
                    )
                }
            }
        }
    }
}
