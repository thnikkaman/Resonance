import SwiftUI
import UIKit

enum AppTab: Hashable {
  case playing, library, streaming, settings

  static let allCases: [AppTab] = [.playing, .library, .streaming, .settings]
}

@MainActor
final class ResonanceTabNavigation: ObservableObject {
  @Published var selection: AppTab = .library
  @Published private(set) var requestID = 0

  func select(_ tab: AppTab) {
    selection = tab
    requestID &+= 1
  }
}

@MainActor
final class ResonanceGestureCoordinator: ObservableObject {
  @Published private(set) var isHorizontalSwipeSuppressed = false
  private var resetTask: Task<Void, Never>?

  func beginHorizontalSwipe() {
    resetTask?.cancel()
    isHorizontalSwipeSuppressed = true
  }

  func endHorizontalSwipe() {
    resetTask?.cancel()
    resetTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(320))
      guard !Task.isCancelled else { return }
      self?.isHorizontalSwipeSuppressed = false
    }
  }
}

private struct ResonanceMiniPlayerBottomInsetKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

struct ResonanceTabSwipeActions: @unchecked Sendable {
  let onChanged: (CGFloat, CGFloat) -> Void
  let onEnded: (CGFloat, CGFloat) -> Void

  static let inactive = ResonanceTabSwipeActions(
    onChanged: { _, _ in },
    onEnded: { _, _ in }
  )
}

private struct ResonanceTabSwipeActionsKey: EnvironmentKey {
  static let defaultValue = ResonanceTabSwipeActions.inactive
}

extension EnvironmentValues {
  var resonanceMiniPlayerBottomInset: CGFloat {
    get { self[ResonanceMiniPlayerBottomInsetKey.self] }
    set { self[ResonanceMiniPlayerBottomInsetKey.self] = newValue }
  }

  var resonanceTabSwipeActions: ResonanceTabSwipeActions {
    get { self[ResonanceTabSwipeActionsKey.self] }
    set { self[ResonanceTabSwipeActionsKey.self] = newValue }
  }
}

struct ResonanceTabSwipeObserver: ViewModifier {
  @Environment(\.resonanceTabSwipeActions) private var actions

  func body(content: Content) -> some View {
    content.simultaneousGesture(
      DragGesture(minimumDistance: 5, coordinateSpace: .local)
        .onChanged { value in
          actions.onChanged(value.translation.width, value.translation.height)
        }
        .onEnded { value in
          actions.onEnded(value.translation.width, value.translation.height)
        }
    )
  }
}

struct ResonanceSwipeAwareButtonStyle: PrimitiveButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ResonanceSwipeAwareButtonBody(configuration: configuration)
  }
}

private struct ResonanceSwipeAwareButtonBody: View {
  let configuration: PrimitiveButtonStyle.Configuration

  var body: some View {
    configuration.label
      .contentShape(Rectangle())
      .highPriorityGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onEnded { value in
            guard abs(value.translation.width) < 8,
                  abs(value.translation.height) < 8
            else { return }
            configuration.trigger()
          }
      )
  }
}

extension View {
  func resonanceTabSwipeObserver() -> some View {
    modifier(ResonanceTabSwipeObserver())
  }

}

enum MiniPlayerDock: String {
  case top, bottom, leading, trailing
}

@MainActor
final class ResonanceMiniPlayerNavigation: ObservableObject {
  @Published var dock: MiniPlayerDock = .bottom
}

enum ResonanceBrowseRoot: String {
  case library, streaming
}

enum ResonanceLayer: Int {
  case root = 0, artist = 1, allAlbums = 2, album = 3, player = 4, settings = 5
}

@MainActor
final class ResonanceLayerNavigation: ObservableObject {
  @Published var root: ResonanceBrowseRoot = .library
  @Published var layer: ResonanceLayer = .root
  // Keep the layered container informed only about playback presence, not
  // every PlayerController publication. Playback details stay local to the
  // mini-player and Now Playing subtree.
  @Published private(set) var hasCurrentTrack = false
  @Published var localArtist: Artist?
  @Published var localAlbum: Album?
  @Published var localAllAlbumsArtistName: String?
  @Published var localAllAlbumsTracks: [Track]?
  @Published var remoteArtist: RemoteArtist?
  @Published var remoteAlbum: RemoteAlbum?
  @Published var remoteAllAlbumsArtistName: String?
  @Published var remoteAllAlbumsTracks: [RemoteTrackItem]?
  private var layerBeforeSettings: ResonanceLayer = .root

  func showPlayer() {
    withAnimation(.easeInOut(duration: 0.35)) {
      layer = .player
    }
  }

  func showAlbum() {
    guard localAlbum != nil || remoteAlbum != nil else { return }
    withAnimation(.easeInOut(duration: 0.35)) {
      layer = .album
    }
  }

  func showLocalAllAlbums(artistName: String, tracks: [Track]) {
    localAllAlbumsArtistName = artistName
    localAllAlbumsTracks = tracks
    remoteAllAlbumsArtistName = nil
    remoteAllAlbumsTracks = nil
    layer = .allAlbums
  }

  func showRemoteAllAlbums(artistName: String, tracks: [RemoteTrackItem]) {
    remoteAllAlbumsArtistName = artistName
    remoteAllAlbumsTracks = tracks
    localAllAlbumsArtistName = nil
    localAllAlbumsTracks = nil
    layer = .allAlbums
  }

  func showArtist() {
    guard localArtist != nil || remoteArtist != nil else { return }
    layer = .artist
  }

  func showRemoteArtist(_ artist: RemoteArtist) {
    remoteArtist = artist
    localArtist = nil
    withAnimation(.easeInOut(duration: 0.35)) {
      layer = .artist
    }
  }

  func showLocalAlbum(_ album: Album) {
    localAlbum = album
    remoteAlbum = nil
    withAnimation(.easeInOut(duration: 0.35)) {
      layer = .album
    }
  }

  func showRemoteAlbum(_ album: RemoteAlbum) {
    remoteAlbum = album
    localAlbum = nil
    withAnimation(.easeInOut(duration: 0.35)) {
      layer = .album
    }
  }

  func showRoot() {
    localArtist = nil
    localAlbum = nil
    localAllAlbumsArtistName = nil
    localAllAlbumsTracks = nil
    remoteArtist = nil
    remoteAlbum = nil
    remoteAllAlbumsArtistName = nil
    remoteAllAlbumsTracks = nil
    layer = .root
  }

  func setCurrentTrackPresence(_ hasTrack: Bool) {
    guard hasCurrentTrack != hasTrack else { return }
    hasCurrentTrack = hasTrack
  }

  func showLibraryRoot() {
    ResonanceDiagnostics.shared.recordDeferred(
      "navigation.root.switch",
      details: ["destination": "library"]
    )
    root = .library
    showRoot()
  }

  func showStreamingRoot() {
    ResonanceDiagnostics.shared.recordDeferred(
      "navigation.root.switch",
      details: ["destination": "streaming"]
    )
    root = .streaming
    showRoot()
  }

  func showSettings() {
    layerBeforeSettings = layer
    withAnimation(.easeInOut(duration: 0.28)) {
      layer = .settings
    }
  }

  func closeSettings() {
    withAnimation(.easeInOut(duration: 0.28)) {
      layer = layerBeforeSettings
    }
  }
}

private struct ResonanceLayeredNavigationActiveKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var resonanceLayeredNavigationActive: Bool {
    get { self[ResonanceLayeredNavigationActiveKey.self] }
    set { self[ResonanceLayeredNavigationActiveKey.self] = newValue }
  }
}

private struct ResonanceLayeredNavigationView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
  @EnvironmentObject private var miniPlayerNavigation: ResonanceMiniPlayerNavigation
  @StateObject private var navigation = ResonanceLayerNavigation()
  @State private var hasPresentedStreaming = false

  var body: some View {
    ZStack {
      // Extend the active page surface behind the home-indicator area while
      // keeping the GeometryReader and its controls inside the safe area.
      ResonanceThemeBackdrop()
        .ignoresSafeArea()

      GeometryReader { proxy in
        ZStack(alignment: .top) {
        ResonanceLayeredPlaybackCoordinator(navigation: navigation)
          .frame(width: 0, height: 0)

        rootSurface
          .offset(y: offset(for: .root, height: proxy.size.height))
          .zIndex(0)

        if let artist = navigation.localArtist {
          NavigationStack {
            ArtistDetailView(artist: artist)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showRoot() }
          .resonanceFrameDebug("Artist: Local")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .artist, height: proxy.size.height))
          .zIndex(1)
        } else if let artist = navigation.remoteArtist {
          NavigationStack {
            RemoteArtistDetailView(artist: artist)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showRoot() }
          .resonanceFrameDebug("Artist: Streaming")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .artist, height: proxy.size.height))
          .zIndex(1)
          .animation(.easeInOut(duration: 0.35), value: navigation.layer)
          .onAppear {
            ResonanceDiagnostics.shared.recordDeferred(
              "navigation.remoteArtistDetail.presented",
              details: ["layer": "artist"]
            )
          }
        }

        if let artistName = navigation.localAllAlbumsArtistName,
           let tracks = navigation.localAllAlbumsTracks {
          NavigationStack {
            AllAlbumsTrackListView(artistName: artistName, tracks: tracks)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showArtist() }
          .resonanceFrameDebug("All Albums: Local")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .allAlbums, height: proxy.size.height))
          .zIndex(2)
        } else if let artistName = navigation.remoteAllAlbumsArtistName,
                  let tracks = navigation.remoteAllAlbumsTracks {
          NavigationStack {
            RemoteAllAlbumsTrackListView(artistName: artistName, tracks: tracks)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showArtist() }
          .resonanceFrameDebug("All Albums: Streaming")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .allAlbums, height: proxy.size.height))
          .zIndex(2)
        }

        if let album = navigation.localAlbum {
          NavigationStack {
            AlbumDetailView(album: album)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showArtist() }
          .resonanceFrameDebug("Album: Local")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .album, height: proxy.size.height))
          .zIndex(3)
          .animation(.easeInOut(duration: 0.35), value: navigation.layer)
        } else if let album = navigation.remoteAlbum {
          NavigationStack {
            RemoteAlbumDetailView(album: album)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          .layeredSurface { navigation.showArtist() }
          .resonanceFrameDebug("Album: Streaming")
          .transition(.move(edge: .bottom))
          .offset(y: offset(for: .album, height: proxy.size.height))
          .zIndex(3)
          .animation(.easeInOut(duration: 0.35), value: navigation.layer)
        }

        NavigationStack {
          NowPlayingView(openLibrary: navigation.showRoot)
        }
        .environment(\.resonanceLayeredNavigationActive, true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
        .layeredSurface { navigation.showAlbum() }
        .resonanceFrameDebug("Player")
        .offset(y: offset(for: .player, height: proxy.size.height))
        .zIndex(4)

        if navigation.layer == .settings {
          NavigationStack {
            SettingsView(closeSettings: navigation.closeSettings)
          }
          .environment(\.resonanceLayeredNavigationActive, true)
          .toolbarBackground(.hidden, for: .navigationBar)
          .background(Color.clear)
          // Settings is not dismissible with a downward swipe. Its explicit
          // navigation controls remain available, while the page keeps all
          // vertical drags for normal Form scrolling.
          .layeredSurface()
          .resonanceFrameDebug("Settings")
          .transition(.move(edge: .bottom))
          .zIndex(10)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        // The page backdrop owns the full phone surface, including the
        // status-bar safe area. The layer header remains inside the safe area
        // so its controls stay below the clock and system indicators.
        ResonanceThemeBackdrop()
          .ignoresSafeArea()
      }
      .overlay(alignment: .top) {
        ResonanceLayerHeader(navigation: navigation)
      }
        .overlay(alignment: .top) {
        if miniPlayerNavigation.dock == .top,
           navigation.hasCurrentTrack,
           navigation.layer != .player,
           navigation.layer != .settings {
          ResonanceLayeredMiniPlayerOverlay(navigation: navigation)
            // Keep the top-docked player at one consistent position below
            // each module's navigation/header controls and above its content.
            .padding(.top, 150)
        }
      }
      .overlay(alignment: .bottom) {
        if miniPlayerNavigation.dock == .bottom,
           navigation.hasCurrentTrack,
           navigation.layer != .player,
           navigation.layer != .settings {
          ResonanceLayeredMiniPlayerOverlay(navigation: navigation)
        }
      }
      .onChange(of: navigation.root) { _, root in
        if root == .streaming {
          hasPresentedStreaming = true
        }
        navigation.showRoot()
      }
        }
    }
    .ignoresSafeArea(edges: .bottom)
    .foregroundStyle(settings.textAccentColor)
    .environmentObject(navigation)
    .environment(\.resonanceLayeredNavigationActive, true)
    .environment(\.resonanceMiniPlayerBottomInset, navigation.hasCurrentTrack ? 76 : 0)
    .environmentObject(gestureCoordinator)
    .environmentObject(miniPlayerNavigation)
  }

  @ViewBuilder
  private var rootSurface: some View {
    ZStack {
      if navigation.root == .library || !hasPresentedStreaming {
        NavigationStack {
          LibraryView(
            openStreaming: navigation.showStreamingRoot,
            openSettings: navigation.showSettings
          )
        }
        .opacity(navigation.root == .library ? 1 : 0)
        .allowsHitTesting(navigation.root == .library)
        .accessibilityHidden(navigation.root != .library)
      }
      if navigation.root == .streaming || hasPresentedStreaming {
        NavigationStack {
          StreamingLibraryView(
            openLibrary: navigation.showLibraryRoot,
            openSettings: navigation.showSettings
          )
        }
        .opacity(navigation.root == .streaming ? 1 : 0)
        .allowsHitTesting(navigation.root == .streaming)
        .accessibilityHidden(navigation.root != .streaming)
      }
    }
    .environment(\.resonanceLayeredNavigationActive, true)
    .toolbarBackground(.hidden, for: .navigationBar)
    .background(Color.clear)
    .layeredSurface()
  }

  private func offset(for layer: ResonanceLayer, height: CGFloat) -> CGFloat {
    switch navigation.layer {
    case .root:
      return layer == .root ? 0 : height
    case .artist:
      return layer.rawValue <= ResonanceLayer.artist.rawValue ? 0 : height
    case .allAlbums:
      return layer.rawValue <= ResonanceLayer.allAlbums.rawValue ? 0 : height
    case .album:
      return layer.rawValue <= ResonanceLayer.album.rawValue ? 0 : height
    case .player:
      return layer.rawValue <= ResonanceLayer.player.rawValue ? 0 : height
    case .settings:
      return layer == .settings ? 0 : 0
    }
  }

}

private struct ResonanceLayeredPlaybackCoordinator: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var remote: RemoteLibraryStore
  @ObservedObject var navigation: ResonanceLayerNavigation

  var body: some View {
    Color.clear
      .onAppear {
        synchronizeTrackPresence()
        prepareCurrentContext()
      }
      .onChange(of: player.currentTrack?.id) { _, _ in
        synchronizeTrackPresence()
      }
      .onChange(of: player.nowPlayingPresentationRequest) { _, _ in
        prepareCurrentContext()
        navigation.showPlayer()
      }
  }

  private func synchronizeTrackPresence() {
    navigation.setCurrentTrackPresence(player.currentTrack != nil)
  }

  private func prepareCurrentContext() {
    guard let track = player.currentTrack else { return }
    if track.isRemote, let remoteTrack = remote.tracks.first(where: { $0.id == track.id }) {
      navigation.root = .streaming
      navigation.remoteAlbum = remote.albums.first {
        $0.tracks.contains(where: { $0.id == remoteTrack.id })
      }
      navigation.remoteArtist = remote.artists.first {
        $0.tracks.contains(where: { $0.id == remoteTrack.id })
      }
      navigation.localAlbum = nil
      navigation.localArtist = nil
    } else {
      navigation.root = .library
      navigation.localAlbum = library.albums.first {
        $0.tracks.contains(where: { $0.id == track.id })
      }
      navigation.localArtist = library.artists.first {
        $0.albums.contains(where: { $0.tracks.contains(where: { $0.id == track.id }) })
      }
      navigation.remoteAlbum = nil
      navigation.remoteArtist = nil
    }
  }
}

private struct ResonanceLayeredMiniPlayerOverlay: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var miniPlayerNavigation: ResonanceMiniPlayerNavigation
  @ObservedObject var navigation: ResonanceLayerNavigation

  var body: some View {
    MiniPlayerView(
      dock: miniPlayerNavigation.dock,
      openNowPlaying: {
        navigation.showPlayer()
      },
      onDock: { miniPlayerNavigation.dock = $0 }
    )
    .padding(.horizontal, 8)
    .padding(.bottom, 8)
    .resonanceFrameDebug("Mini Player")
  }
}

private struct ResonanceLayerHeader: View {
  @ObservedObject var navigation: ResonanceLayerNavigation
  @EnvironmentObject private var settings: AppSettings

  var body: some View {
    Group {
      switch navigation.layer {
      case .root:
        EmptyView()
      case .artist:
        EmptyView()
      case .allAlbums:
        EmptyView()
      case .album:
        EmptyView()
      case .player:
        EmptyView()
      case .settings:
        EmptyView()
      }
    }
    .font(.headline.weight(.semibold))
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .background(Color.clear)
    .contentShape(Rectangle())
    .resonanceFrameDebug("Layer Header")
  }

  private func layerButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      ResonanceHierarchyNavigationLabel(title: title)
    }
    .accessibilityLabel("(title), move up")
  }
}

struct ResonanceHierarchyNavigationLabel: View {
  @EnvironmentObject private var settings: AppSettings
  let title: String
  let systemImage: String

  init(title: String, systemImage: String = "arrow.up") {
    self.title = title
    self.systemImage = systemImage
  }

  private var shape: Capsule { Capsule() }

  @ViewBuilder
  private var surface: some View {
    switch settings.heroButtonStyle {
    case .softGlass:
      shape.fill(.ultraThinMaterial)
        .overlay { shape.fill(settings.accentColor.opacity(0.10)) }
    case .matteCrystal:
      shape.fill(settings.themeSurfaceColor.opacity(0.42))
        .overlay {
          LinearGradient(
            colors: [Color.white.opacity(0.10), Color.clear, settings.accentColor.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .clipShape(shape)
        }
    case .innerGlow:
      shape.fill(settings.accentColor.opacity(0.045))
    case .minimalTransparent:
      Color.clear
    }
  }

  @ViewBuilder
  private var outline: some View {
    switch settings.heroButtonStyle {
    case .softGlass:
      shape.stroke(settings.accentColor.opacity(0.55), lineWidth: 1)
    case .matteCrystal:
      shape.stroke(settings.accentColor.opacity(0.68), lineWidth: 1)
    case .innerGlow:
      ZStack {
        shape.stroke(settings.accentColor.opacity(0.32), lineWidth: 5).blur(radius: 3)
        shape.stroke(settings.accentColor.opacity(0.78), lineWidth: 1)
      }
    case .minimalTransparent:
      Color.clear
    }
  }

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .light))
    }
    .font(.subheadline.weight(.semibold))
    .padding(.horizontal, 14)
    .frame(height: 34)
    .background {
      surface
    }
    .overlay {
      outline
    }
    .foregroundStyle(settings.textAccentColor)
    .contentShape(Capsule())
    .fixedSize(horizontal: true, vertical: true)
  }
}

extension ToolbarContent {
  @ToolbarContentBuilder
  func resonanceHideSharedBackground() -> some ToolbarContent {
    if #available(iOS 26.0, *) {
      self.sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
    }
}

private struct ResonanceSecondaryToolbarActionModifier: ViewModifier {
    let title: String
    let systemImage: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            ResonanceToolbarTextButton(
                title: title,
                systemImage: systemImage,
                action: action
            )
            .padding(.top, -4)
            .padding(.trailing, 12)
        }
    }
}

extension View {
    func resonanceSecondaryToolbarAction(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            ResonanceSecondaryToolbarActionModifier(
                title: title,
                systemImage: systemImage,
                action: action
            )
        )
    }
}

private struct ResonanceFrameDiagnosticsModifier: ViewModifier {
  @EnvironmentObject private var settings: AppSettings
  let label: String

  func body(content: Content) -> some View {
    content.overlay {
      if settings.showFrameDiagnostics {
        Rectangle()
          .stroke(Color.red, lineWidth: 1 / UIScreen.main.scale)
          .overlay {
            Text(label)
              .font(.system(size: 9, weight: .semibold, design: .monospaced))
              .foregroundStyle(.red)
              .padding(.horizontal, 3)
              .padding(.vertical, 1)
              .background(Color.black.opacity(0.78))
              .allowsHitTesting(false)
          }
          .allowsHitTesting(false)
      }
    }
  }
}

private extension View {
  func resonanceFrameDebug(_ label: String) -> some View {
    modifier(ResonanceFrameDiagnosticsModifier(label: label))
  }

  func layeredSurface() -> some View {
    self
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background { ResonanceThemeBackdrop() }
      .clipped()
  }

  func layeredSurface(onDown: @escaping () -> Void) -> some View {
    layeredSurface()
      .simultaneousGesture(
        DragGesture(minimumDistance: 45, coordinateSpace: .local)
          .onEnded { value in
            // Detail dismissal belongs to the upper hero/header region.
            // Track and album scrolling starts below it and must remain
            // ordinary vertical scrolling instead of navigating away.
            guard value.startLocation.y < 340,
                  value.translation.height > 70,
                  value.translation.height > abs(value.translation.width) + 4
            else { return }
            onDown()
          }
      )
  }
}

struct RootView: View {
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var settings: AppSettings
  @StateObject private var tabNavigation = ResonanceTabNavigation()
  @StateObject private var gestureCoordinator = ResonanceGestureCoordinator()
  @StateObject private var miniPlayerNavigation = ResonanceMiniPlayerNavigation()
  @State private var tabSwipeOffset: CGFloat = 0
  @State private var isCompletingTabSwipe = false
  @State private var isTabSwipeActive = false

  private var selectedTab: AppTab {
    get { tabNavigation.selection }
    set { tabNavigation.select(newValue) }
  }

    var body: some View {
        ZStack {
            ResonanceThemeBackdrop()
            ResonanceLayeredNavigationView()
                .environmentObject(gestureCoordinator)
                .environmentObject(miniPlayerNavigation)
                .environmentObject(tabNavigation)
                // PlayerController is already injected by ResonanceApp. Do
                // not read and reinject it here: RootView also owns both
                // browse modules, and reading the controller at this level
                // would make the whole navigation tree a playback observer.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    var legacyBody: some View {
        ZStack {
            activeTabContent
                .environmentObject(gestureCoordinator)
                .environmentObject(miniPlayerNavigation)
                .environment(
                    \.resonanceMiniPlayerBottomInset,
                    miniPlayerNavigation.dock == .bottom
                        && player.currentTrack != nil
                        ? 100
                        : 0
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if miniPlayerNavigation.dock == .bottom,
                       player.currentTrack != nil {
                        Color.clear.frame(height: 74)
                    }
                }
                .resonanceThemeTextSurface()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackCoordinatorView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ErrorReportingCoordinatorView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            if miniPlayerNavigation.dock == .leading {
                MiniPlayerEdgeHandle(isVisible: selectedTab != .playing, edge: .leading) {
                    tabNavigation.select(.playing)
                } onUndock: {
                    miniPlayerNavigation.dock = .top
                } onDock: { dock in
                    miniPlayerNavigation.dock = dock
                }
                .padding(.leading, 2)
            }
        }
        .overlay(alignment: .trailing) {
            if miniPlayerNavigation.dock == .trailing {
                MiniPlayerEdgeHandle(isVisible: selectedTab != .playing, edge: .trailing) {
                    tabNavigation.select(.playing)
                } onUndock: {
                    miniPlayerNavigation.dock = .top
                } onDock: { dock in
                    miniPlayerNavigation.dock = dock
                }
                .padding(.trailing, 2)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if miniPlayerNavigation.dock == .top,
               player.currentTrack != nil {
                MiniPlayerOverlay(
                    isVisible: true,
                    dock: .top,
                    openNowPlaying: { tabNavigation.select(.playing) },
                    onDock: { miniPlayerNavigation.dock = $0 }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .opacity(selectedTab == .playing ? 0 : 1)
                .allowsHitTesting(selectedTab != .playing)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if miniPlayerNavigation.dock == .bottom, player.currentTrack != nil {
                    MiniPlayerOverlay(
                        isVisible: true,
                        dock: .bottom,
                        openNowPlaying: { tabNavigation.select(.playing) },
                        onDock: { miniPlayerNavigation.dock = $0 }
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    .opacity(selectedTab == .playing ? 0 : 1)
                    .allowsHitTesting(selectedTab != .playing)
                }
                ResonanceTabBar()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
        .onChange(of: player.nowPlayingPresentationRequest) { _, _ in
            showPlayingTab()
        }
        .environmentObject(tabNavigation)
    }

    private func showPlayingTab() {
        guard tabNavigation.selection != .playing else { return }
        tabNavigation.select(.playing)
    }

    @ViewBuilder
    private var activeTabContent: some View {
        GeometryReader { proxy in
            ZStack {
                tabPage(.playing, width: proxy.size.width) {
                    NowPlayingView(
                        openLibrary: { tabNavigation.select(.library) },
                        onHorizontalTabSwipeChanged: { horizontal, vertical in
                            updateTabSwipe(horizontal, vertical: vertical)
                        },
                        onHorizontalTabSwipeEnded: { horizontal, vertical in
                            finishTabSwipe(
                                horizontal,
                                vertical: vertical,
                                width: proxy.size.width
                            )
                        }
                    )
                }
                tabPage(.library, width: proxy.size.width) {
                    LibraryView(
                        openStreaming: { tabNavigation.select(.streaming) },
                        openSettings: { tabNavigation.select(.settings) }
                    )
                }
                tabPage(.streaming, width: proxy.size.width) {
                    StreamingLibraryView(
                        openLibrary: { tabNavigation.select(.library) },
                        openSettings: { tabNavigation.select(.settings) }
                    )
                }
                tabPage(.settings, width: proxy.size.width) {
                    SettingsView(closeSettings: { tabNavigation.select(.library) })
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .environment(
                \.resonanceTabSwipeActions,
                ResonanceTabSwipeActions(
                    onChanged: { horizontal, vertical in
                        updateTabSwipe(horizontal, vertical: vertical)
                    },
                    onEnded: { horizontal, vertical in
                        finishTabSwipe(
                            horizontal,
                            vertical: vertical,
                            width: proxy.size.width
                        )
                    }
                )
            )
            // Playing has its own upper-content gesture so the artwork pager
            // can retain exclusive ownership of album-art drags. Keeping the
            // root recognizer off that page avoids an otherwise invisible
            // ancestor gesture competing with the artwork pager.
            .modifier(
                ResonanceConditionalTabSwipeModifier(
                    isEnabled: selectedTab != .playing,
                    gesture: tabSwipeGesture(width: proxy.size.width)
                )
            )
        }
    }

    @ViewBuilder
    private func tabPage<Content: View>(
        _ tab: AppTab,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            ZStack {
                ResonanceThemeBackdrop()
                content()
            }
        }
        .frame(width: width)
        .offset(x: tabPageOffset(tab, width: width))
        .opacity(tabPageIsVisible(tab) ? 1 : 0)
        // Once a horizontal transition has started, the source page must not
        // receive the release. Its cards would otherwise treat the same touch
        // as an album/artist tap while the root page is still moving.
        .allowsHitTesting(
            tab == selectedTab
                && (!isTabSwipeActive || tab == .playing)
        )
        .accessibilityHidden(tab != selectedTab)
        .scrollDisabled(isTabSwipeActive)
    }

    private func tabSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                guard selectedTab != .playing else { return }
                updateTabSwipe(value.translation.width, vertical: value.translation.height)
            }
            .onEnded { value in
                guard selectedTab != .playing else { return }
                finishTabSwipe(
                    value.translation.width,
                    vertical: value.translation.height,
                    width: width
                )
            }
    }

    private func updateTabSwipe(_ horizontal: CGFloat, vertical: CGFloat = 0) {
        guard !isCompletingTabSwipe,
              abs(horizontal) >= 8,
              abs(horizontal) > abs(vertical) + 4
        else { return }
        isTabSwipeActive = true
        gestureCoordinator.beginHorizontalSwipe()
        let direction = horizontal < 0 ? 1 : -1
        let targetIndex = tabIndex(selectedTab) + direction
        guard AppTab.allCases.indices.contains(targetIndex) else {
            tabSwipeOffset = horizontal * 0.18
            return
        }
        tabSwipeOffset = horizontal
    }

    private func finishTabSwipe(
        _ horizontal: CGFloat,
        vertical: CGFloat = 0,
        width: CGFloat
    ) {
        guard !isCompletingTabSwipe,
              abs(horizontal) >= 8,
              abs(horizontal) > abs(vertical) + 4
        else {
            cancelTabSwipe()
            return
        }

        let direction = horizontal < 0 ? 1 : -1
        let targetIndex = tabIndex(selectedTab) + direction
        // Require a deliberate half-screen commit. The live offset still
        // follows the finger, but shorter drags spring back to this tab.
        let threshold = width * 0.5
        guard AppTab.allCases.indices.contains(targetIndex),
              abs(horizontal) >= threshold
        else {
            cancelTabSwipe()
            return
        }

        isCompletingTabSwipe = true
        withAnimation(.easeOut(duration: 0.2)) {
            tabSwipeOffset = direction > 0 ? -width : width
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(210))
            guard !Task.isCancelled else { return }
                    tabNavigation.select(AppTab.allCases[targetIndex])
            tabSwipeOffset = 0
            isCompletingTabSwipe = false
            isTabSwipeActive = false
            gestureCoordinator.endHorizontalSwipe()
        }
    }

    private func cancelTabSwipe() {
        withAnimation(.easeOut(duration: 0.16)) {
            tabSwipeOffset = 0
            isTabSwipeActive = false
        }
        gestureCoordinator.endHorizontalSwipe()
    }

    private func tabIndex(_ tab: AppTab) -> Int {
        AppTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func tabPageIsVisible(_ tab: AppTab) -> Bool {
        let distance = abs(tabIndex(tab) - tabIndex(selectedTab))
        return distance == 0 || (tabSwipeOffset != 0 && distance == 1)
    }

    private func tabPageOffset(_ tab: AppTab, width: CGFloat) -> CGFloat {
        let baseOffset = CGFloat(tabIndex(tab) - tabIndex(selectedTab)) * width
        return baseOffset + (tabPageIsVisible(tab) ? tabSwipeOffset : 0)
    }
}

private struct ResonanceConditionalTabSwipeModifier<G: Gesture>: ViewModifier {
    let isEnabled: Bool
    let gesture: G

    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(gesture)
        } else {
            content
        }
    }
}

struct ResonanceTabBar: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var tabNavigation: ResonanceTabNavigation

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.playing, title: "Playing", systemImage: "music.note")
            tabButton(.library, title: "Library", systemImage: "square.stack")
            tabButton(.streaming, title: "Streaming Library", systemImage: "network")
            tabButton(.settings, title: "Settings", systemImage: "gearshape")
        }
        .padding(.horizontal, 8)
        .padding(.top, 0)
        .padding(.bottom, 0)
        .offset(y: 20)
        // Keep the bar at the original position and carry its themed surface
        // through the home-indicator area so no black footer is exposed.
        .background {
            ZStack {
                settings.themeSurfaceColor
                settings.themeSurfaceGradient.opacity(0.78)
            }
                .padding(.top, 10)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
                .offset(y: 10)
        }
        .zIndex(100)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func tabButton(_ tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                tabNavigation.select(tab)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tabNavigation.selection == tab ? settings.accentColor : settings.themeSecondaryColor)
        .accessibilityLabel(title)
        .accessibilityAddTraits(tabNavigation.selection == tab ? .isSelected : [])
    }
}

struct ResonanceDetailTabNavigation: ViewModifier {
  @Environment(\.dismiss) private var dismiss
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var tabNavigation: ResonanceTabNavigation
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var miniPlayerNavigation: ResonanceMiniPlayerNavigation

    func body(content: Content) -> some View {
        content
            // Keep hierarchy dismissal attached to the detail surface before
            // the tab bar is added as a safe-area inset. The detail content
            // follows the finger while the navigation bar remains docked.
            .resonanceTopDownDismiss { dismiss() }
            .overlay(alignment: .leading) {
                if !layeredNavigation, miniPlayerNavigation.dock == .leading {
                    MiniPlayerEdgeHandle(isVisible: true, edge: .leading) {
                        tabNavigation.select(.playing)
                    } onUndock: {
                        miniPlayerNavigation.dock = .top
                    } onDock: { dock in
                        miniPlayerNavigation.dock = dock
                    }
                    .padding(.leading, 2)
                }
            }
            .overlay(alignment: .trailing) {
                if !layeredNavigation, miniPlayerNavigation.dock == .trailing {
                    MiniPlayerEdgeHandle(isVisible: true, edge: .trailing) {
                        tabNavigation.select(.playing)
                    } onUndock: {
                        miniPlayerNavigation.dock = .top
                    } onDock: { dock in
                        miniPlayerNavigation.dock = dock
                    }
                    .padding(.trailing, 2)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !layeredNavigation,
                   miniPlayerNavigation.dock == .top, player.currentTrack != nil {
                    MiniPlayerOverlay(
                        isVisible: true,
                        dock: .top,
                        openNowPlaying: { tabNavigation.select(.playing) },
                        onDock: { miniPlayerNavigation.dock = $0 }
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !layeredNavigation {
                    VStack(spacing: 0) {
                        if miniPlayerNavigation.dock == .bottom, player.currentTrack != nil {
                            MiniPlayerOverlay(
                                isVisible: true,
                                dock: .bottom,
                                openNowPlaying: { tabNavigation.select(.playing) },
                                onDock: { miniPlayerNavigation.dock = $0 }
                            )
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                        }
                        ResonanceTabBar()
                    }
                }
            }
            .onChange(of: tabNavigation.requestID) { _, _ in
                dismiss()
            }
            // A play action can originate inside a full-screen detail layer.
            // Dismiss that layer directly when playback requests Now Playing,
            // so the root tab transition is visible immediately instead of
            // leaving the detail cover above the selected tab.
            .onChange(of: player.nowPlayingPresentationRequest) { _, _ in
                if tabNavigation.selection != .playing {
                    tabNavigation.select(.playing)
                }
                dismiss()
            }
    }
}

extension View {
    func resonanceDetailTabNavigation() -> some View {
        modifier(ResonanceDetailTabNavigation())
    }
}

private struct ErrorReportingCoordinatorView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var errorLog: AppErrorLog

    var body: some View {
        Color.clear
            .onChange(of: remote.connectionStatus) { _, status in
                if Self.looksLikeError(status) {
                    errorLog.report(source: "Streaming", message: status)
                }
            }
            .onChange(of: remote.catalogSyncStatus) { _, status in
                if Self.looksLikeError(status) {
                    errorLog.report(source: "Remote Catalog", message: status)
                }
            }
            .onChange(of: library.scanStatus) { _, status in
                if Self.looksLikeError(status) {
                    errorLog.report(source: "Library Scanner", message: status)
                }
            }
    }

    private static func looksLikeError(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return ["error", "failed", "could not", "unable", "invalid", "denied"]
            .contains { lowered.contains($0) }
    }
}

extension View {
    fileprivate func resonanceThemeTextSurface() -> some View {
        modifier(ResonanceThemeTextSurface())
    }

    /// Keeps the final Library/Streaming item above the custom bottom controls.
    /// The mini-player value already includes its larger bottom clearance when
    /// it is docked below the browse surface.
    func resonanceBrowseBottomClearance() -> some View {
        modifier(ResonanceBrowseBottomClearance())
    }

    fileprivate func resonanceMiniPlayerInsets(
        isVisible: Bool,
        dock: MiniPlayerDock,
        openNowPlaying: @escaping () -> Void,
        onDock: @escaping (MiniPlayerDock) -> Void
    ) -> some View {
        modifier(
            MiniPlayerInsets(
                isVisible: isVisible,
                dock: dock,
                openNowPlaying: openNowPlaying,
                onDock: onDock
            )
        )
    }

    func resonanceTabBottomSpace() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 72)
        }
    }

    func resonanceDetailBottomSpace() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            // Keep the final track above the floating mini-player, including
            // on long albums where the list must scroll to its last row.
            Color.clear.frame(height: 128)
        }
    }

    func resonanceTopDownDismiss(_ action: @escaping () -> Void) -> some View {
        modifier(ResonanceInteractiveTopDownDismissModifier(action: action))
    }

    func resonanceHierarchySwipeBack(_ action: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 45, coordinateSpace: .local)
                .onEnded { value in
                    guard value.translation.height > 70,
                          abs(value.translation.height) > abs(value.translation.width)
                    else { return }
                    action()
                }
        )
    }

    func resonanceHeroSurface() -> some View {
        modifier(ResonanceHeroSurface())
    }
}

private struct ResonanceBrowseBottomClearance: ViewModifier {
    func body(content: Content) -> some View {
        // Browse content can extend behind the floating mini-player so the
        // final album artwork reaches the bottom edge instead of stopping at
        // an artificial clearance block.
        content
    }
}

private struct ResonanceInteractiveTopDownDismissModifier: ViewModifier {
    let action: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isCompleting = false

    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset)
            // Share recognition with List/ScrollView. The location and
            // direction guards below make this a header-only dismissal, while
            // high-priority ownership would block every vertical list drag
            // before the scroll view could claim it.
            .simultaneousGesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isCompleting,
                              value.startLocation.y < 150,
                              value.translation.height >= 8,
                              value.translation.height > abs(value.translation.width) + 4
                        else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        guard !isCompleting,
                              value.startLocation.y < 150,
                              value.translation.height >= 8,
                              value.translation.height > abs(value.translation.width) + 4
                        else {
                            cancel()
                            return
                        }

                        guard value.translation.height >= 70 else {
                            cancel()
                            return
                        }

                        isCompleting = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = max(480, value.translation.height * 2.2)
                        }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(210))
                            guard !Task.isCancelled else { return }
                            action()
                            dragOffset = 0
                            isCompleting = false
                        }
                    }
            )
    }

    private func cancel() {
        withAnimation(.easeOut(duration: 0.16)) {
            dragOffset = 0
        }
    }
}

private struct ResonanceThemeTextSurface: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .background(Color.clear)
            .tint(settings.accentColor)
            .foregroundStyle(
                settings.textAccentColor
            )
            .toolbarBackground(
                AnyShapeStyle(Color.clear),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(settings.colorScheme, for: .navigationBar)
    }
}

struct ResonanceThemeBackdrop: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            settings.themeBackgroundGradient
            if settings.visualTheme == .waterfall,
               let customImage = settings.customThemeImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let imageName = settings.visualTheme.backgroundImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        // The custom tab bar owns an opaque surface, so the page artwork can
        // extend behind the system safe areas without obscuring its controls.
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct ResonanceThemeSurfaceBackdrop: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        // Every theme uses genuinely transparent surfaces. The selected
        // gradient or image is the page backdrop; text, artwork, and controls
        // remain visible above it.
        Color.clear
        .allowsHitTesting(false)
    }
}

private struct ResonanceHeroSurface: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                ResonanceThemeSurfaceBackdrop()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 4)
    }
}

struct ResonanceDetailHeroHeader<Content: View>: View {
    @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
    @EnvironmentObject private var miniPlayerNavigation: ResonanceMiniPlayerNavigation
    @EnvironmentObject private var player: PlayerController
    let title: String
    let showsMetadataOverride: Bool
    let reservesTopMiniPlayerClearance: Bool
    let content: Content

    private var topMiniPlayerClearance: CGFloat {
        (layeredNavigation || reservesTopMiniPlayerClearance)
            && miniPlayerNavigation.dock == .top
            && player.currentTrack != nil ? 48 : 0
    }

    init(
        title: String,
        showsMetadataOverride: Bool = false,
        reservesTopMiniPlayerClearance: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsMetadataOverride = showsMetadataOverride
        self.reservesTopMiniPlayerClearance = reservesTopMiniPlayerClearance
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.title3.weight(.bold))
                if showsMetadataOverride {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            content
                .padding(.top, topMiniPlayerClearance)
        }
    }
}

struct ResonanceHeroActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let prominent: Bool
    let action: () -> Void
    @EnvironmentObject private var settings: AppSettings

    private var label: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 64, height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        switch settings.heroButtonStyle {
        case .softGlass:
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(tint.opacity(prominent ? 0.78 : 0.10))
                }
        case .matteCrystal:
            shape
                .fill(settings.themeSurfaceColor.opacity(prominent ? 0.88 : 0.42))
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(prominent ? 0.20 : 0.10),
                            Color.clear,
                            tint.opacity(prominent ? 0.16 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
        case .innerGlow:
            shape.fill(tint.opacity(prominent ? 0.16 : 0.045))
        case .minimalTransparent:
            Color.clear
        }
    }

    @ViewBuilder
    private var outline: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        switch settings.heroButtonStyle {
        case .softGlass:
            shape.stroke(tint.opacity(prominent ? 0.92 : 0.55), lineWidth: 1)
        case .matteCrystal:
            shape.stroke(
                tint.opacity(prominent ? 0.92 : 0.68),
                lineWidth: prominent ? 1.2 : 1
            )
        case .innerGlow:
            ZStack {
                shape.stroke(tint.opacity(0.32), lineWidth: 5)
                    .blur(radius: 3)
                shape.stroke(tint.opacity(prominent ? 0.95 : 0.78), lineWidth: 1)
            }
        case .minimalTransparent:
            Color.clear
        }
    }

    private var styledLabel: some View {
        label
            .foregroundStyle(
                prominent
                    ? settings.contrastingAccentTextColor
                    : settings.textAccentColor
            )
            .background { surface }
            .overlay { outline }
    }

    var body: some View {
        Button(action: action, label: { styledLabel })
        .buttonStyle(.plain)
        .tint(tint)
        .help(title)
        .contextMenu {
            Label(title, systemImage: systemImage)
        }
        .accessibilityLabel(title)
    }
}

struct ResonanceHeroMenuLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    let prominent: Bool
    @EnvironmentObject private var settings: AppSettings

    private var label: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 64, height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        switch settings.heroButtonStyle {
        case .softGlass:
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(tint.opacity(prominent ? 0.78 : 0.10)) }
        case .matteCrystal:
            shape
                .fill(settings.themeSurfaceColor.opacity(prominent ? 0.88 : 0.42))
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(prominent ? 0.20 : 0.10),
                            Color.clear,
                            tint.opacity(prominent ? 0.16 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
        case .innerGlow:
            shape.fill(tint.opacity(prominent ? 0.16 : 0.045))
        case .minimalTransparent:
            Color.clear
        }
    }

    @ViewBuilder
    private var outline: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        switch settings.heroButtonStyle {
        case .softGlass:
            shape.stroke(tint.opacity(prominent ? 0.92 : 0.55), lineWidth: 1)
        case .matteCrystal:
            shape.stroke(
                tint.opacity(prominent ? 0.92 : 0.68),
                lineWidth: prominent ? 1.2 : 1
            )
        case .innerGlow:
            ZStack {
                shape.stroke(tint.opacity(0.32), lineWidth: 5)
                    .blur(radius: 3)
                shape.stroke(tint.opacity(prominent ? 0.95 : 0.78), lineWidth: 1)
            }
        case .minimalTransparent:
            Color.clear
        }
    }

    var body: some View {
        label
            .foregroundStyle(
                prominent
                    ? settings.contrastingAccentTextColor
                    : settings.textAccentColor
            )
            .background { surface }
            .overlay { outline }
    }
}


struct ResonanceToolbarIconButton: View {
    let accessibilityLabel: String
    let systemImage: String
    let action: () -> Void
    @EnvironmentObject private var settings: AppSettings

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    @ViewBuilder
    private var surface: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(settings.accentColor.opacity(0.10))
                }
        case .matteCrystal:
            shape
                .fill(settings.themeSurfaceColor.opacity(0.42))
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                            settings.accentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
        case .innerGlow:
            shape.fill(settings.accentColor.opacity(0.045))
        case .minimalTransparent:
            Color.clear
        }
    }

    @ViewBuilder
    private var outline: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape.stroke(settings.accentColor.opacity(0.55), lineWidth: 1)
        case .matteCrystal:
            shape.stroke(settings.accentColor.opacity(0.68), lineWidth: 1)
        case .innerGlow:
            ZStack {
                shape.stroke(settings.accentColor.opacity(0.32), lineWidth: 5)
                    .blur(radius: 3)
                shape.stroke(settings.accentColor.opacity(0.78), lineWidth: 1)
            }
        case .minimalTransparent:
            Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
            .frame(width: 32, height: 34)
            .background {
                surface
            }
            .overlay {
                outline
            }
            .foregroundStyle(settings.textAccentColor)
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .help(accessibilityLabel)
            .accessibilityLabel(accessibilityLabel)
    }
}

struct ResonanceToolbarIconLabel: View {
    let systemImage: String
    @EnvironmentObject private var settings: AppSettings

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    @ViewBuilder
    private var surface: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(settings.accentColor.opacity(0.10))
                }
        case .matteCrystal:
            shape
                .fill(settings.themeSurfaceColor.opacity(0.42))
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                            settings.accentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
        case .innerGlow:
            shape.fill(settings.accentColor.opacity(0.045))
        case .minimalTransparent:
            Color.clear
        }
    }

    @ViewBuilder
    private var outline: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape.stroke(settings.accentColor.opacity(0.55), lineWidth: 1)
        case .matteCrystal:
            shape.stroke(settings.accentColor.opacity(0.68), lineWidth: 1)
        case .innerGlow:
            ZStack {
                shape.stroke(settings.accentColor.opacity(0.32), lineWidth: 5)
                    .blur(radius: 3)
                shape.stroke(settings.accentColor.opacity(0.78), lineWidth: 1)
            }
        case .minimalTransparent:
            Color.clear
        }
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.semibold))
            // Keep passive labels used by NavigationLink/Menu at the same
            // geometry as ResonanceToolbarIconButton.
            .frame(width: 32, height: 34)
            .background {
                surface
            }
            .overlay {
                outline
            }
            .foregroundStyle(settings.textAccentColor)
    }
}

struct ResonanceToolbarTextButton: View {
    let title: String
    let systemImage: String
    let width: CGFloat
    let action: () -> Void
    @EnvironmentObject private var settings: AppSettings

    init(
        title: String,
        systemImage: String,
        width: CGFloat = 112,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.width = width
        self.action = action
    }

    private var shape: Capsule { Capsule() }

    @ViewBuilder
    private var surface: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape.fill(.ultraThinMaterial)
                .overlay { shape.fill(settings.accentColor.opacity(0.10)) }
        case .matteCrystal:
            shape.fill(settings.themeSurfaceColor.opacity(0.42))
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear, settings.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
        case .innerGlow:
            shape.fill(settings.accentColor.opacity(0.045))
        case .minimalTransparent:
            Color.clear
        }
    }

    @ViewBuilder
    private var outline: some View {
        switch settings.heroButtonStyle {
        case .softGlass:
            shape.stroke(settings.accentColor.opacity(0.55), lineWidth: 1)
        case .matteCrystal:
            shape.stroke(settings.accentColor.opacity(0.68), lineWidth: 1)
        case .innerGlow:
            ZStack {
                shape.stroke(settings.accentColor.opacity(0.32), lineWidth: 5).blur(radius: 3)
                shape.stroke(settings.accentColor.opacity(0.78), lineWidth: 1)
            }
        case .minimalTransparent:
            Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .frame(width: width, height: 30)
            .background { surface }
            .overlay { outline }
            .foregroundStyle(settings.textAccentColor)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct MiniPlayerInsets: ViewModifier {
    @EnvironmentObject private var player: PlayerController
    let isVisible: Bool
    let dock: MiniPlayerDock
    let openNowPlaying: () -> Void
    let onDock: (MiniPlayerDock) -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if isVisible, dock == .top, player.currentTrack != nil {
                    MiniPlayerOverlay(
                        isVisible: isVisible,
                        dock: .top,
                        openNowPlaying: openNowPlaying,
                        onDock: onDock
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 95)
                    .padding(.bottom, 6)
                }
            }
    }
}

private struct MiniPlayerOverlay: View {
  @EnvironmentObject private var player: PlayerController
  let isVisible: Bool
  let dock: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onDock: (MiniPlayerDock) -> Void

  var body: some View {
    if isVisible, player.currentTrack != nil {
      MiniPlayerView(
        dock: dock,
        openNowPlaying: openNowPlaying,
        onDock: onDock
      )
      .accessibilityHint("Use the arrow to move this player between the top and bottom")
    }
  }
}

private struct MiniPlayerEdgeHandle: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var player: PlayerController
  @Environment(\.resonanceLayeredNavigationActive) private var layeredNavigation
  @GestureState private var dragTranslation = CGSize.zero
  let isVisible: Bool
  let edge: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onUndock: () -> Void
  let onDock: (MiniPlayerDock) -> Void

  var body: some View {
    if isVisible, player.currentTrack != nil, !layeredNavigation {
      Button(action: openNowPlaying) {
        HStack(spacing: 3) {
          if let track = player.currentTrack {
            ArtworkView(
              data: player.artworkData(for: track),
              embedded: player.artworkIsEmbedded(for: track),
              size: 32
            )
          }
          Image(systemName: edge == .leading ? "chevron.right" : "chevron.left")
            .font(.caption.weight(.bold))
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
          Capsule()
            .fill(settings.themeSurfaceGradient.opacity(0.28))
        }
        .overlay(Capsule().stroke(settings.accentColor.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .offset(dragTranslation)
      .contentShape(Rectangle())
      .zIndex(10)
      .simultaneousGesture(
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
          .updating($dragTranslation) { value, state, _ in
            state = value.translation
          }
          .onEnded { value in
            let horizontal = abs(value.translation.width)
            let vertical = abs(value.translation.height)
            let returnsInward = edge == .leading
              ? value.translation.width > 35
              : value.translation.width < -35
            if vertical > horizontal, vertical > 70 {
              onDock(value.translation.height < 0 ? .top : .bottom)
            } else if returnsInward {
              onUndock()
            }
          }
      )
      .accessibilityLabel("Show mini player")
      .accessibilityHint("Swipe inward to return the mini player to the top")
    }
  }
}

private struct PlaybackCoordinatorView: View {
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var errorLog: AppErrorLog

    var body: some View {
        Color.clear
            .onAppear {
                player.onRuntimeError = { source, message in
                    errorLog.report(source: source, message: message)
                }
                player.onTrackStarted = { track in
                    if track.isRemote {
                        Task { await remote.markPlayed(trackID: track.id, using: settings) }
                    } else {
                        library.markPlayed(track)
                    }
                }
            }
            .onChange(of: settings.preloadNextTrack) { _, _ in
                player.refreshPlaybackConfiguration()
            }
            .onChange(of: settings.localBufferMB) { _, _ in
                player.refreshPlaybackConfiguration()
            }
            .onChange(of: settings.networkBufferMB) { _, _ in
                player.refreshPlaybackConfiguration()
            }
            .onChange(of: settings.showLockScreenArtwork) { _, _ in
                player.refreshNowPlayingMetadata()
            }
    }
}
