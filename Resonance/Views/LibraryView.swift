import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: AppSettings
    @State private var importing = false
    @State private var showingLibraryOptions = false
    let openStreaming: () -> Void
    let openSettings: () -> Void

    init(
        openStreaming: @escaping () -> Void = {},
        openSettings: @escaping () -> Void = {}
    ) {
        self.openStreaming = openStreaming
        self.openSettings = openSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if library.isScanning && library.tracks.isEmpty {
                    ProgressView("Indexing music…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if library.isBootstrapping && library.tracks.isEmpty {
                    ProgressView("Loading cached library…")
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
            .overlay(alignment: .topLeading) {
                if library.grouping == .artists || library.grouping == .albumArtists {
                    Text(
                        library.grouping == .artists
                            ? "Local Library"
                            : "Album Artists"
                    )
                    .font(.title3.weight(.bold))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
            }
        }
        .navigationTitle(library.grouping == .artists ? "Library" : library.grouping.rawValue)
        .toolbarTitleDisplayMode(.inline)
        .background {
            ResonanceThemeBackdrop()
        }
        .resonanceSecondaryToolbarAction(
            title: "Browse Files",
            systemImage: "folder.badge.plus",
            action: { importing = true }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: library.grouping == .albums
                            ? "Album view settings"
                            : library.grouping == .artists || library.grouping == .albumArtists
                                ? "Artist view settings"
                                : "Library view and sort options",
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
                .frame(width: 112, alignment: .leading)
            }
            .resonanceHideSharedBackground()

            ToolbarItem(placement: .principal) {
                Button(action: openStreaming) {
                    ResonanceHierarchyNavigationLabel(
                        title: "Streaming",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.plain)
                .help("Open Streaming library")
                .accessibilityLabel("Streaming, move right")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Scan Resonance Music folder",
                        systemImage: "arrow.clockwise"
                    ) {
                        Task { await library.scanSharedMusicFolder(forceMetadataRefresh: false) }
                    }
                    .disabled(library.isScanning)

                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Open Settings",
                        systemImage: "gearshape",
                        action: openSettings
                    )
                }
            }
            .resonanceHideSharedBackground()
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

struct LibraryOptionsSheet: View {
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

/// Keeps alphabetized grid content in one continuous grid so a section can
/// end in the middle of a row and the next section can use the remaining
/// cells. Section labels remain attached to the first tile of each section,
/// while their scroll targets continue to work with the alphabet index.
struct ResonanceAlphabetGrid<Item: Identifiable, Tile: View>: View {
    @EnvironmentObject private var settings: AppSettings

    private struct Entry: Identifiable {
        let id: Int
        let item: Item
        let sectionKey: String
        let isFirstInSection: Bool
        let rowNeedsHeaderSpace: Bool
    }

    let sections: [ArtistIndexSection<Item>]
    let columns: [GridItem]
    let sectionIDPrefix: String
    let sectionLabelColor: Color?
    let leadingCellCount: Int
    let leadingContent: AnyView?
    let tileContent: (Item) -> Tile

    init(
        sections: [ArtistIndexSection<Item>],
        columns: [GridItem],
        sectionIDPrefix: String,
        sectionLabelColor: Color? = nil,
        leadingCellCount: Int = 0,
        leadingContent: AnyView? = nil,
        @ViewBuilder tileContent: @escaping (Item) -> Tile
    ) {
        self.sections = sections
        self.columns = columns
        self.sectionIDPrefix = sectionIDPrefix
        self.sectionLabelColor = sectionLabelColor
        self.leadingCellCount = leadingCellCount
        self.leadingContent = leadingContent
        self.tileContent = tileContent
    }

    private var entries: [Entry] {
        let rawEntries = sections.flatMap { section in
            section.items.enumerated().map { offset, item in
                (item, section.key, offset == 0)
            }
        }
        let columnCount = max(columns.count, 1)
        let headerRows = Set(
            rawEntries.enumerated().compactMap { index, entry in
                entry.2 ? (index + leadingCellCount) / columnCount : nil
            }
        )
        return rawEntries.enumerated().map { index, entry in
            Entry(
                id: index,
                item: entry.0,
                sectionKey: entry.1,
                isFirstInSection: entry.2,
                rowNeedsHeaderSpace: headerRows.contains((index + leadingCellCount) / columnCount)
            )
        }
    }

    private var firstRowNeedsHeaderSpace: Bool {
        entries.first?.rowNeedsHeaderSpace == true
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            if let leadingContent {
                if firstRowNeedsHeaderSpace {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 22)
                        leadingContent
                    }
                } else {
                    leadingContent
                }
            }

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    if entry.rowNeedsHeaderSpace {
                        if entry.isFirstInSection {
                            Text(entry.sectionKey)
                                .font(.headline)
                                .foregroundStyle(sectionLabelColor ?? settings.textAccentColor)
                                .frame(height: 22, alignment: .leading)
                        } else {
                            Color.clear.frame(height: 22)
                        }
                    }
                    tileContent(entry.item)
                }
                .id(entry.isFirstInSection ? "\(sectionIDPrefix)-\(entry.sectionKey)" : "\(sectionIDPrefix)-item-\(entry.id)")
            }
        }
    }
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
    @EnvironmentObject private var settings: AppSettings

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
    // Keep the letters in their existing 32-point visual column while giving
    // the gesture a small edge-side extension so the glyphs themselves are
    // inside the hit region.
    private let indexHitWidth: CGFloat = 48
    private let bubbleSize: CGFloat = 86
    private let verticalInset: CGFloat = 8

    private var indexAlignment: Alignment {
        settings.leftHandedAlphabet ? .topLeading : .topTrailing
    }

    private var bubbleHorizontalOffset: CGFloat {
        settings.leftHandedAlphabet
            ? bubbleSize + indexColumnWidth + 10
            : -(bubbleSize + indexColumnWidth + 10)
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(1, geometry.size.height - verticalInset * 2)
            let rowHeight = min(18, max(9, floor(availableHeight / CGFloat(max(keys.count, 1)))))
            let indexHeight = rowHeight * CGFloat(keys.count)
            let topInset = max(verticalInset, (geometry.size.height - indexHeight) / 2)

            ZStack(alignment: indexAlignment) {
                VStack(spacing: 0) {
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: rowHeight < 11 ? 8 : 10, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(settings.textAccentColor)
                            .frame(width: indexColumnWidth, height: rowHeight)
                    }
                }
                .offset(y: topInset)
                .allowsHitTesting(false)

                if let selectedKey {
                    Text(selectedKey)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(settings.textAccentColor)
                        .minimumScaleFactor(0.55)
                        .frame(width: bubbleSize, height: bubbleSize)
                        .background {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.32),
                                                Color.cyan.opacity(0.28),
                                                Color.blue.opacity(0.18)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Ellipse()
                                    .fill(Color.white.opacity(0.28))
                                    .frame(width: bubbleSize * 0.52, height: bubbleSize * 0.18)
                                    .blur(radius: 4)
                                    .offset(x: -bubbleSize * 0.12, y: -bubbleSize * 0.25)
                            }
                            .clipShape(Circle())
                        }
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.7),
                                            Color.cyan.opacity(0.75),
                                            Color.blue.opacity(0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.25
                                )
                        }
                        .shadow(color: Color.cyan.opacity(0.28), radius: 8)
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        .offset(
                            x: bubbleHorizontalOffset,
                            y: topInset + CGFloat(selectedRow) * rowHeight + (rowHeight - bubbleSize) / 2
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: indexAlignment)
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
                    .onEnded { value in
                        let releaseY = value.location.y
                        // Reissue the final selection after the gesture has
                        // ended. The initial onChanged callback can be
                        // consumed while the scroll view is still handling
                        // the touch; force the release callback so a direct
                        // tap never needs a second touch.
                        Task { @MainActor in
                            await Task.yield()
                            selectRow(
                                at: releaseY,
                                topInset: topInset,
                                rowHeight: rowHeight,
                                repeatSelection: true
                            )
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
                    }
            )
        }
        .frame(width: indexHitWidth)
        .frame(maxHeight: .infinity)
        .accessibilityLabel("Alphabet index")
    }

    private func selectRow(
        at y: CGFloat,
        topInset: CGFloat,
        rowHeight: CGFloat,
        repeatSelection: Bool = false
    ) {
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
        let selectionChanged = gestureKey != key
        if selectionChanged {
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
        }
        if selectionChanged || repeatSelection {
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
    @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
    @EnvironmentObject private var layeredNavigation: ResonanceLayerNavigation
    @State private var artistToRemove: Artist?
    @State private var artistToEdit: Artist?
    @State private var presentedArtist: Artist?
    @State private var cachedIndexedSections: [ArtistIndexSection<Artist>] = []
    let artists: [Artist]

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    private var indexedSections: [ArtistIndexSection<Artist>] {
        cachedIndexedSections
    }

    private var indexedSectionsKey: String {
        let identity = artists.map { "\($0.id)|\($0.name)" }.joined(separator: ";")
        return "\(library.sortDirection.rawValue)|\(identity)"
    }

    private func makeIndexedSections() -> [ArtistIndexSection<Artist>] {
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
            ZStack(alignment: settings.leftHandedAlphabet ? .leading : .trailing) {
                Group {
                    switch settings.albumLayout {
                    case .grid:
                        ScrollView {
                            ResonanceAlphabetGrid(
                                sections: indexedSections,
                                columns: gridColumns,
                                sectionIDPrefix: "artist-section"
                            ) { artist in
                                Button {
                                    guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        layeredNavigation.localArtist = artist
                                        layeredNavigation.layer = .artist
                                    }
                                } label: {
                                    ArtistTile(artist: artist)
                                }
                                .buttonStyle(.plain)
                                .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                .contextMenu {
                                    Button { artistToEdit = artist } label: {
                                        Label("Edit Artist Metadata", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { artistToRemove = artist } label: {
                                        Label("Remove Artist from Library", systemImage: "trash")
                                    }
                                }
                            }
                            .padding(.leading, settings.leftHandedAlphabet ? 40 : 16)
                            .padding(.trailing, settings.leftHandedAlphabet ? 16 : 40)
                            .padding(.top, 84)
                            .padding(.bottom)
                        }
                        .resonanceBrowseBottomClearance()

                    case .compact, .large:
                        List {
                            ForEach(indexedSections, id: \.key) { section in
                                Section {
                                    ForEach(section.items) { artist in
                                        Button {
                                            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                            withAnimation(.easeInOut(duration: 0.35)) {
                                                layeredNavigation.localArtist = artist
                                                layeredNavigation.layer = .artist
                                            }
                                        } label: {
                                            ArtistListRow(artist: artist, large: settings.albumLayout == .large)
                                        }
                                        .buttonStyle(ResonanceSwipeAwareButtonStyle())
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
                                                leading: settings.leftHandedAlphabet ? 40 : 16,
                                                bottom: settings.albumLayout == .compact ? 2 : 8,
                                                trailing: settings.leftHandedAlphabet ? 16 : 40
                                            )
                                        )
                                        .listRowBackground(Color.clear)
                                    }
                                } header: {
                                    Text(section.key)
                                        .foregroundStyle(settings.textAccentColor)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .id("artist-section-\(section.key)")
                            }
                        }
                        .listStyle(.plain)
                        .listRowBackground(Color.clear)
                        .scrollContentBackground(.hidden)
                        .safeAreaPadding(.top, 84)
                        .resonanceBrowseBottomClearance()
                    }
                }

                if indexedSections.count > 1 {
                    VerticalArtistIndex(keys: indexedSections.map(\.key)) { key in
                        proxy.scrollTo("artist-section-\(key)", anchor: .top)
                    }
                    .padding(.leading, settings.leftHandedAlphabet ? 1 : 0)
                    .padding(.trailing, settings.leftHandedAlphabet ? 0 : 1)
                    .padding(.vertical, 4)
                }
            }
        }
        .task(id: indexedSectionsKey) {
            cachedIndexedSections = makeIndexedSections()
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
        .fullScreenCover(item: $presentedArtist) { artist in
            NavigationStack {
                ArtistDetailView(artist: artist)
            }
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

struct ArtistAlbumLayoutToggle: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            layoutButton(.grid, systemImage: "square.grid.2x2")
            layoutButton(.list, systemImage: "list.bullet")
        }
        .padding(3)
        .background(.ultraThinMaterial.opacity(0.32), in: Capsule())
        .overlay {
            Capsule()
                .stroke(settings.accentColor.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Album view")
    }

    private func layoutButton(_ layout: ArtistAlbumLayout, systemImage: String) -> some View {
        Button {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                settings.artistAlbumLayout = layout
            }
        } label: {
            Label(layout.rawValue, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            (layout == .grid && settings.artistAlbumLayout == .grid && settings.albumLayout == .grid)
                || (layout == .list && (settings.artistAlbumLayout != .grid || settings.albumLayout != .grid))
                ? settings.accentColor
                : settings.themeSecondaryColor
        )
    }
}

struct ArtistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
    @EnvironmentObject private var layeredNavigationState: ResonanceLayerNavigation
    @State private var artistToEdit: Artist?
    @State private var albumToEdit: Album?
    @State private var albumToRemove: Album?
    @State private var showingLibraryOptions = false
    @State private var showingPlaylistPicker = false
    @State private var presentedAlbum: Album?
    @State private var showingAllAlbums = false
    @State private var cachedLiveArtist: Artist?
    let artist: Artist

    private var liveArtist: Artist { cachedLiveArtist ?? artist }

    private var liveArtistKey: String {
        "\(artist.id)|\(library.browseRevision)"
    }

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

    @ViewBuilder
    private func audiobookMenu(for album: Album) -> some View {
        let marked = player.isAudiobook(albumArtist: album.artist, album: album.title)
        Button {
            player.toggleAudiobook(albumArtist: album.artist, album: album.title)
        } label: {
            Label(marked ? "Unmark as Audiobook" : "Mark as Audiobook", systemImage: marked ? "book.closed.fill" : "book.closed")
        }
    }

    private var allTracks: [Track] {
        liveArtist.albums.flatMap(\.tracks).sorted { lhs, rhs in
            let albumComparison = lhs.album.localizedStandardCompare(rhs.album)
            if albumComparison != .orderedSame { return albumComparison == .orderedAscending }
            if lhs.discNumber != rhs.discNumber { return lhs.discNumber < rhs.discNumber }
            if lhs.trackNumber != rhs.trackNumber { return lhs.trackNumber < rhs.trackNumber }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private var indexedAlbumSections: [ArtistIndexSection<Album>] {
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

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ResonanceDetailHeroHeader(
                title: liveArtist.name,
                showsMetadataOverride: liveArtist.hasMetadataOverride,
                reservesTopMiniPlayerClearance: true
            ) {
                VStack(spacing: 4) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 6) {
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

                        VStack(spacing: 6) {
                            ResonanceHeroActionButton(title: "Edit", systemImage: "pencil", tint: settings.accentColor, prominent: false) {
                                artistToEdit = liveArtist
                            }
                            ResonanceHeroActionButton(title: "Add to Queue", systemImage: "text.append", tint: settings.accentColor, prominent: false) {
                                player.addToQueue(allTracks)
                            }
                        }
                    }
                    .disabled(allTracks.isEmpty)
                }
                .contentShape(Rectangle())
                .resonanceHeroSurface()
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
            }

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
                ZStack(alignment: settings.leftHandedAlphabet ? .leading : .trailing) {
                    Group {
                        if settings.artistAlbumLayout == .grid && settings.albumLayout == .grid {
                            ScrollView {
                                ResonanceAlphabetGrid(
                                    sections: indexedAlbumSections,
                                    columns: gridColumns,
                                    sectionIDPrefix: "artist-album-section",
                                    leadingCellCount: 1,
                                    leadingContent: AnyView(
                                        Button {
                                            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                            if layeredNavigation {
                                                withAnimation(.easeInOut(duration: 0.35)) {
                                                    layeredNavigationState.showLocalAllAlbums(
                                                        artistName: liveArtist.name,
                                                        tracks: allTracks
                                                    )
                                                }
                                            } else {
                                                showingAllAlbums = true
                                            }
                                        } label: {
                                            AllAlbumsTile(artist: liveArtist)
                                        }
                                        .buttonStyle(.plain)
                                        .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                    )
                                ) { album in
                                    Button {
                                        guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                        layeredNavigationState.showLocalAlbum(album)
                                    } label: {
                                        AlbumTile(album: album)
                                    }
                                    .buttonStyle(.plain)
                                    .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                    .contextMenu {
                                        Button { albumToEdit = album } label: {
                                            Label("Edit Album Metadata", systemImage: "pencil")
                                        }
                                        audiobookMenu(for: album)
                                        Divider()
                                        Button { albumToRemove = album } label: {
                                            Label("Remove or Delete Album", systemImage: "trash")
                                        }
                                    }
                                }
                                .padding(.leading, settings.leftHandedAlphabet ? 40 : 16)
                                .padding(.trailing, settings.leftHandedAlphabet ? 16 : 40)
                                .padding(.bottom)
                            }
                            .resonanceBrowseBottomClearance()
                            .background {
                                ResonanceThemeSurfaceBackdrop()
                            }
                        } else {
                            List {
                                Button {
                                    guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                    if layeredNavigation {
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            layeredNavigationState.showLocalAllAlbums(
                                                artistName: liveArtist.name,
                                                tracks: allTracks
                                            )
                                        }
                                    } else {
                                        showingAllAlbums = true
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        PlaceholderArtwork(
                                            symbol: "square.stack.3d.up.fill",
                                            size: settings.albumLayout == .compact ? 42 : settings.albumLayout == .large ? 76 : 58
                                        )
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("All Albums").font(.headline)
                                            Text("\(allTracks.count) tracks, grouped by album")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                .listRowBackground(Color.clear)

                                ForEach(indexedAlbumSections, id: \.key) { section in
                                    Section {
                                        ForEach(section.items) { album in
                                            Button {
                                                guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                                                layeredNavigationState.showLocalAlbum(album)
                                            } label: {
                                                HStack(spacing: 12) {
                                                    ArtworkView(
                                                        data: album.artworkData,
                                                        embedded: album.artworkIsEmbedded,
                                                        size: settings.albumLayout == .compact ? 42 : settings.albumLayout == .large ? 76 : 58
                                                    )
                                                    VStack(alignment: .leading, spacing: settings.albumLayout == .compact ? 1 : 3) {
                                                        Text(album.title).font(settings.libraryTextSize.font.weight(.semibold)).lineLimit(1)
                                                        Text(album.yearLabel)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                            .buttonStyle(ResonanceSwipeAwareButtonStyle())
                                            .listRowBackground(Color.clear)
                                            .contextMenu {
                                                Button { albumToEdit = album } label: {
                                                    Label("Edit Album Metadata", systemImage: "pencil")
                                                }
                                                audiobookMenu(for: album)
                                                Divider()
                                                Button { albumToRemove = album } label: {
                                                    Label("Remove or Delete Album", systemImage: "trash")
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
                            .safeAreaPadding(.leading, settings.leftHandedAlphabet ? 36 : 0)
                            .safeAreaPadding(.trailing, settings.leftHandedAlphabet ? 0 : 36)
                            .resonanceBrowseBottomClearance()
                            .background(Color.clear)
                        }
                    }

                    if indexedAlbumSections.count > 1 {
                        VerticalArtistIndex(
                            keys: indexedAlbumSections.map(\.key),
                            diagnosticSurface: "library-artist-albums"
                        ) { key in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("artist-album-section-\(key)", anchor: .top)
                            }
                        }
                        .zIndex(2)
                        .padding(.leading, settings.leftHandedAlphabet ? 1 : 0)
                        .padding(.trailing, settings.leftHandedAlphabet ? 0 : 1)
                        .padding(.vertical, 4)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .task(id: liveArtistKey) {
            cachedLiveArtist = library.refreshedArtist(artist)
        }
        .background {
            // This destination owns the page backdrop so the theme remains
            // visible when an artist is pushed from the library list.
            ResonanceThemeBackdrop()
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
            .resonanceHideSharedBackground()
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Artist view settings",
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
                            layeredNavigationState.showRoot()
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    ResonanceHierarchyNavigationLabel(title: "Library")
                }
                .accessibilityLabel("Library, move up")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    ResonanceToolbarIconButton(
                        accessibilityLabel: "Edit artist metadata",
                        systemImage: "pencil"
                    ) {
                        artistToEdit = liveArtist
                    }

                    ResonanceToolbarIconButton(
                        accessibilityLabel: library.playlists.isEmpty ? "Add a playlist" : "Add artist to playlist",
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
            PlaylistPickerSheet(tracks: allTracks)
                .presentationDetents([.medium, .large])
        }
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
        .fullScreenCover(item: $presentedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
            }
        }
        .fullScreenCover(isPresented: $showingAllAlbums) {
            NavigationStack {
                AllAlbumsTrackListView(artistName: liveArtist.name, tracks: allTracks)
            }
        }
        .resonanceTabSwipeObserver()
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
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
    @EnvironmentObject private var layeredNavigation: ResonanceLayerNavigation
    @State private var albumToEdit: Album?
    @State private var albumToRemove: Album?
    @State private var presentedAlbum: Album?
    @State private var cachedIndexedSections: [ArtistIndexSection<Album>] = []
    let albums: [Album]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: settings.libraryThumbnailSize.gridColumnCount
        )
    }

    private var indexedSections: [ArtistIndexSection<Album>] {
        cachedIndexedSections
    }

    private var indexedSectionsKey: String {
        let identity = albums.map { "\($0.id)|\($0.title)" }.joined(separator: ";")
        return "\(library.sortDirection.rawValue)|\(identity)"
    }

    @ViewBuilder
    private func audiobookMenu(for album: Album) -> some View {
        Button {
            player.toggleAudiobook(albumArtist: album.artist, album: album.title)
        } label: {
            Label(
                player.isAudiobook(albumArtist: album.artist, album: album.title)
                    ? "Unmark as Audiobook"
                    : "Mark as Audiobook",
                systemImage: player.isAudiobook(albumArtist: album.artist, album: album.title)
                    ? "book.closed.fill"
                    : "book.closed"
            )
        }
    }

    private func makeIndexedSections() -> [ArtistIndexSection<Album>] {
        let grouped = Dictionary(grouping: albums) { resonanceArtistIndexKey($0.title) }
        let preferredOrder = resonanceArtistIndexOrder(
            for: Array(grouped.keys),
            ascending: library.sortDirection == .ascending
        )
        return preferredOrder.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            let sorted = values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return ArtistIndexSection(
                key: key,
                items: library.sortDirection == .ascending ? sorted : Array(sorted.reversed())
            )
        }
    }

    @ViewBuilder
    private func albumRow(_ album: Album) -> some View {
        Button {
            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
            layeredNavigation.localAlbum = album
            layeredNavigation.layer = .album
        } label: {
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
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contextMenu {
            Button { albumToEdit = album } label: {
                Label("Edit Album Metadata", systemImage: "pencil")
            }
            audiobookMenu(for: album)
            Divider()
            Button { albumToRemove = album } label: {
                Label("Remove or Delete Album", systemImage: "trash")
            }
        }
        .listRowInsets(
            EdgeInsets(
                top: settings.albumLayout == .compact ? 2 : 8,
                leading: settings.leftHandedAlphabet ? 40 : 16,
                bottom: settings.albumLayout == .compact ? 2 : 8,
                trailing: settings.leftHandedAlphabet ? 16 : 40
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: settings.leftHandedAlphabet ? .leading : .trailing) {
                Group {
            if settings.albumLayout == .grid {
                ScrollView {
                    ResonanceAlphabetGrid(
                        sections: indexedSections,
                        columns: columns,
                        sectionIDPrefix: "album-section"
                    ) { album in
                        Button {
                            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                            layeredNavigation.localAlbum = album
                            layeredNavigation.layer = .album
                        } label: {
                            AlbumTile(album: album)
                        }
                        .buttonStyle(.plain)
                        .buttonStyle(ResonanceSwipeAwareButtonStyle())
                        .contextMenu {
                            Button { albumToEdit = album } label: {
                                Label("Edit Album Metadata", systemImage: "pencil")
                            }
                            audiobookMenu(for: album)
                            Divider()
                            Button { albumToRemove = album } label: {
                                Label("Remove or Delete Album", systemImage: "trash")
                            }
                        }
                    }
                    .padding(.leading, settings.leftHandedAlphabet ? 40 : 16)
                    .padding(.trailing, settings.leftHandedAlphabet ? 16 : 40)
                    .padding(.top, 84)
                    .padding(.bottom)
                }
                .resonanceBrowseBottomClearance()
            } else {
                List {
                    ForEach(indexedSections, id: \.key) { section in
                        Section {
                            ForEach(section.items) { album in
                                albumRow(album)
                            }
                        } header: {
                            Text(section.key)
                                .foregroundStyle(settings.textAccentColor)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .id("album-section-\(section.key)")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.top, 84)
                .resonanceBrowseBottomClearance()
            }
                }

                if indexedSections.count > 1 {
                    VerticalArtistIndex(
                        keys: indexedSections.map(\.key),
                        diagnosticSurface: "albums"
                    ) { key in
                        proxy.scrollTo("album-section-\(key)", anchor: .top)
                    }
                    .padding(.leading, settings.leftHandedAlphabet ? 1 : 0)
                    .padding(.trailing, settings.leftHandedAlphabet ? 0 : 1)
                    .padding(.vertical, 4)
                }
            }
        }
        .task(id: indexedSectionsKey) {
            cachedIndexedSections = makeIndexedSections()
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
        .fullScreenCover(item: $presentedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
            }
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
                                        size: settings.libraryThumbnailSize.gridArtworkPoints,
                                        fallbackTrack: StreamingArtworkTrackQuery(
                                            artist: track.artist,
                                            albumArtist: track.albumArtist,
                                            album: track.album,
                                            title: track.title
                                        )
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
                .resonanceBrowseBottomClearance()
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .resonanceBrowseBottomClearance()
            }
        }
    }
}
