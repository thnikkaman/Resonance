import SwiftUI
import UIKit

enum AppTab: Hashable {
  case playing, library, streaming, settings
}

private enum MiniPlayerDock: String {
  case top, bottom, leading, trailing
}

struct RootView: View {
  @State private var selectedTab: AppTab = .library
  @State private var miniPlayerDock: MiniPlayerDock = .top

    var body: some View {
        ZStack {
            activeTabContent
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ResonanceTabBar(selection: $selectedTab)
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
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .playing:
            NavigationStack {
                NowPlayingView(openLibrary: { selectedTab = .library })
                    .resonanceMiniPlayerInsets(
                        isVisible: false,
                        dock: miniPlayerDock,
                        openNowPlaying: { selectedTab = .playing },
                        onDock: { miniPlayerDock = $0 }
                    )
            }
        case .library:
            NavigationStack {
                LibraryView()
                    .resonanceMiniPlayerInsets(
                        isVisible: true,
                        dock: miniPlayerDock,
                        openNowPlaying: { selectedTab = .playing },
                        onDock: { miniPlayerDock = $0 }
                    )
            }
        case .streaming:
            NavigationStack {
                StreamingLibraryView(
                    openLibrary: { selectedTab = .library },
                    openSettings: { selectedTab = .settings }
                )
                .resonanceMiniPlayerInsets(
                    isVisible: true,
                    dock: miniPlayerDock,
                    openNowPlaying: { selectedTab = .playing },
                    onDock: { miniPlayerDock = $0 }
                )
            }
        case .settings:
            NavigationStack {
                SettingsView(openLibrary: { selectedTab = .library })
                    .resonanceMiniPlayerInsets(
                        isVisible: true,
                        dock: miniPlayerDock,
                        openNowPlaying: { selectedTab = .playing },
                        onDock: { miniPlayerDock = $0 }
                    )
            }
        }
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
        .padding(.top, 7)
        .padding(.bottom, 7)
        .background(settings.themeSurfaceColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
        }
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
        .foregroundStyle(selection == tab ? settings.accentColor : Color.secondary)
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

    func resonanceHeroSurface() -> some View {
        modifier(ResonanceHeroSurface())
    }
}

private struct ResonanceThemeTextSurface: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .background {
                ResonanceThemeBackdrop()
            }
            .tint(settings.accentColor)
            .foregroundStyle(
                settings.textAccentColor
            )
            .toolbarBackground(settings.themeSurfaceGradient, for: .navigationBar)
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
                    .opacity(0.16)
                LinearGradient(
                    colors: [.black.opacity(0.14), .black.opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                settings.themeBackgroundGradient
                    .opacity(0.34)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct ResonanceThemeSurfaceBackdrop: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            settings.themeSurfaceGradient
            if let imageName = settings.visualTheme.backgroundImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(0.07)
                settings.themeSurfaceGradient
                    .opacity(0.70)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ResonanceHeroSurface: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                ResonanceThemeSurfaceBackdrop()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.25), lineWidth: 1)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
    let isVisible: Bool
    let dock: MiniPlayerDock
    let openNowPlaying: () -> Void
    let onDock: (MiniPlayerDock) -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if isVisible, dock == .top {
                    Color.clear.frame(height: 74)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isVisible, dock == .bottom {
                    Color.clear.frame(height: 74)
                }
            }
            .overlay(alignment: .top) {
                if isVisible, dock == .top {
                    MiniPlayerOverlay(
                        isVisible: isVisible,
                        dock: .top,
                        openNowPlaying: openNowPlaying,
                        onDock: onDock
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            }
            .overlay(alignment: .bottom) {
                if isVisible, dock == .bottom {
                    MiniPlayerOverlay(
                        isVisible: isVisible,
                        dock: .bottom,
                        openNowPlaying: openNowPlaying,
                        onDock: onDock
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
    }
}

private struct MiniPlayerOverlay: View {
  @EnvironmentObject private var player: PlayerController
  @GestureState private var dragTranslation = CGSize.zero
  let isVisible: Bool
  let dock: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onDock: (MiniPlayerDock) -> Void

  var body: some View {
    if isVisible, player.currentTrack != nil {
        MiniPlayerView(openNowPlaying: openNowPlaying)
            .offset(dragTranslation)
        .highPriorityGesture(
          DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
              state = value.translation
            }
            .onEnded { value in
              let horizontal = abs(value.translation.width)
              let vertical = abs(value.translation.height)
              if horizontal > vertical, horizontal > 70 {
                onDock(value.translation.width < 0 ? .trailing : .leading)
              } else if vertical > 70 {
                onDock(value.translation.height < 0 ? .top : .bottom)
              }
            }
        )
        .accessibilityHint("Swipe to dock this player at the top, bottom, or side of the screen")
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
        .background(settings.themeSurfaceGradient, in: Capsule())
        .overlay(Capsule().stroke(settings.accentColor.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .offset(dragTranslation)
      .contentShape(Rectangle())
      .zIndex(10)
      .highPriorityGesture(
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
