import SwiftUI
import UIKit

enum AppTab: Hashable {
  case playing, library, streaming, settings

  static let allCases: [AppTab] = [.playing, .library, .streaming, .settings]
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

struct ResonanceTabSwipeGesture: ViewModifier {
  @Environment(\.resonanceTabSwipeActions) private var actions

  func body(content: Content) -> some View {
    content.simultaneousGesture(
      DragGesture(minimumDistance: 18, coordinateSpace: .local)
        .onChanged { value in
          actions.onChanged(value.translation.width, value.translation.height)
        }
        .onEnded { value in
          actions.onEnded(value.translation.width, value.translation.height)
        }
    )
  }
}

extension View {
  func resonanceTabSwipeGesture() -> some View {
    modifier(ResonanceTabSwipeGesture())
  }
}

enum MiniPlayerDock: String {
  case top, bottom, leading, trailing
}

struct RootView: View {
    @EnvironmentObject private var player: PlayerController
  @State private var selectedTab: AppTab = .library
  @State private var miniPlayerDock: MiniPlayerDock = .bottom
  @State private var tabSwipeOffset: CGFloat = 0
  @State private var isCompletingTabSwipe = false

    var body: some View {
        ZStack {
            activeTabContent
                .environment(
                    \.resonanceMiniPlayerBottomInset,
                    miniPlayerDock == .bottom
                        && selectedTab != .playing
                        && player.currentTrack != nil
                        ? 100
                        : 0
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if miniPlayerDock == .bottom,
                       selectedTab != .playing,
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
            if miniPlayerDock == .leading {
                MiniPlayerEdgeHandle(isVisible: selectedTab != .playing, edge: .leading) {
                    selectedTab = .playing
                } onUndock: {
                    miniPlayerDock = .top
                } onDock: { dock in
                    miniPlayerDock = dock
                }
                .padding(.leading, 2)
            }
        }
        .overlay(alignment: .trailing) {
            if miniPlayerDock == .trailing {
                MiniPlayerEdgeHandle(isVisible: selectedTab != .playing, edge: .trailing) {
                    selectedTab = .playing
                } onUndock: {
                    miniPlayerDock = .top
                } onDock: { dock in
                    miniPlayerDock = dock
                }
                .padding(.trailing, 2)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if miniPlayerDock == .top,
               selectedTab != .playing,
               player.currentTrack != nil {
                MiniPlayerOverlay(
                    isVisible: true,
                    dock: .top,
                    openNowPlaying: { selectedTab = .playing },
                    onDock: { miniPlayerDock = $0 }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if miniPlayerDock == .bottom, selectedTab != .playing {
                    MiniPlayerOverlay(
                        isVisible: true,
                        dock: .bottom,
                        openNowPlaying: { selectedTab = .playing },
                        onDock: { miniPlayerDock = $0 }
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
                ResonanceTabBar(selection: $selectedTab)
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
            selectedTab = .playing
        }
    }

    @ViewBuilder
    private var activeTabContent: some View {
        GeometryReader { proxy in
            ZStack {
                tabPage(.playing, width: proxy.size.width) {
                    NowPlayingView(
                        openLibrary: { selectedTab = .library },
                        onHorizontalTabSwipeChanged: { translation in
                            updateTabSwipe(translation)
                        },
                        onHorizontalTabSwipeEnded: { translation in
                            finishTabSwipe(translation, width: proxy.size.width)
                        }
                    )
                }
                tabPage(.library, width: proxy.size.width) {
                    LibraryView()
                }
                tabPage(.streaming, width: proxy.size.width) {
                    StreamingLibraryView(
                        openLibrary: { selectedTab = .library },
                        openSettings: { selectedTab = .settings }
                    )
                }
                tabPage(.settings, width: proxy.size.width) {
                    SettingsView(openLibrary: { selectedTab = .library })
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
            .gesture(tabSwipeGesture(width: proxy.size.width))
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
        .allowsHitTesting(tab == selectedTab)
        .accessibilityHidden(tab != selectedTab)
    }

    private func tabSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
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
              abs(horizontal) > abs(vertical)
        else { return }
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
              abs(horizontal) > abs(vertical)
        else {
            cancelTabSwipe()
            return
        }

        let direction = horizontal < 0 ? 1 : -1
        let targetIndex = tabIndex(selectedTab) + direction
        let threshold = max(72, width * 0.2)
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
            selectedTab = AppTab.allCases[targetIndex]
            tabSwipeOffset = 0
            isCompletingTabSwipe = false
        }
    }

    private func cancelTabSwipe() {
        withAnimation(.easeOut(duration: 0.16)) {
            tabSwipeOffset = 0
        }
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

private struct ResonanceTabBar: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.playing, title: "Playing", systemImage: "music.note")
            tabButton(.library, title: "Library", systemImage: "square.stack")
            tabButton(.streaming, title: "Streaming", systemImage: "network")
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
                selection = tab
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
        .foregroundStyle(selection == tab ? settings.accentColor : settings.themeSecondaryColor)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
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
            Color.clear.frame(height: 96)
        }
    }

    func resonanceTopDownDismiss(_ action: @escaping () -> Void) -> some View {
        highPriorityGesture(
            DragGesture(minimumDistance: 45, coordinateSpace: .local)
                .onEnded { value in
                    guard value.startLocation.y < 150,
                          value.translation.height > 70,
                          abs(value.translation.height) > abs(value.translation.width)
                    else { return }
                    action()
                }
        )
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
            if let imageName = settings.visualTheme.backgroundImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(0.42)
                // Keep a readable veil over the artwork without removing its
                // texture and color from the page background.
                settings.themeBackgroundGradient.opacity(0.12)
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
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.25), lineWidth: 1)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 4)
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

    var body: some View {
        Group {
            if prominent {
                Button(action: action, label: { label })
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(settings.contrastingAccentTextColor)
            } else {
                Button(action: action, label: { label })
                    .buttonStyle(.plain)
                    .foregroundStyle(tint)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .tint(tint)
        .help(title)
        .contextMenu {
            Label(title, systemImage: systemImage)
        }
        .accessibilityLabel(title)
    }
}

struct ResonanceToolbarIconButton: View {
    let accessibilityLabel: String
    let systemImage: String
    let action: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
            .frame(width: 32, height: 30)
            .background {
                ResonanceThemeSurfaceBackdrop()
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.3), lineWidth: 1)
            }
            .foregroundStyle(settings.accentColor)
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .help(accessibilityLabel)
            .accessibilityLabel(accessibilityLabel)
    }
}

struct ResonanceToolbarIconLabel: View {
    let systemImage: String
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.semibold))
            .frame(width: 32, height: 30)
            .background {
                ResonanceThemeSurfaceBackdrop()
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.3), lineWidth: 1)
            }
            .foregroundStyle(settings.accentColor)
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
                    .padding(.top, 90)
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
  @GestureState private var dragTranslation = CGSize.zero
  let isVisible: Bool
  let edge: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onUndock: () -> Void
  let onDock: (MiniPlayerDock) -> Void

  var body: some View {
    if isVisible, player.currentTrack != nil {
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
