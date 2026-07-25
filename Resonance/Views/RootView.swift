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

            PlaybackCoordinatorView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ErrorReportingCoordinatorView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .leading) {
            if miniPlayerDock == .leading {
                MiniPlayerEdgeHandle(isVisible: selectedTab != .playing, edge: .leading) {
                    selectedTab = .playing
                } onUndock: {
                    miniPlayerDock = .top
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
            }
            .resonanceMiniPlayerInsets(
                isVisible: false,
                dock: miniPlayerDock,
                openNowPlaying: { selectedTab = .playing },
                onDock: { miniPlayerDock = $0 }
            )
        case .library:
            NavigationStack { LibraryView() }
                .resonanceMiniPlayerInsets(
                    isVisible: true,
                    dock: miniPlayerDock,
                    openNowPlaying: { selectedTab = .playing },
                    onDock: { miniPlayerDock = $0 }
                )
        case .streaming:
            NavigationStack {
                StreamingLibraryView(
                    openLibrary: { selectedTab = .library },
                    openSettings: { selectedTab = .settings }
                )
            }
                .resonanceMiniPlayerInsets(
                    isVisible: true,
                    dock: miniPlayerDock,
                    openNowPlaying: { selectedTab = .playing },
                    onDock: { miniPlayerDock = $0 }
                )
        case .settings:
            NavigationStack { SettingsView(openLibrary: { selectedTab = .library }) }
                .resonanceMiniPlayerInsets(
                    isVisible: true,
                    dock: miniPlayerDock,
                    openNowPlaying: { selectedTab = .playing },
                    onDock: { miniPlayerDock = $0 }
                )
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
        .background(Color(uiColor: .systemBackground))
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

private extension View {
    func resonanceMiniPlayerInsets(
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
                    MiniPlayerOverlay(
                        isVisible: isVisible,
                        dock: .top,
                        openNowPlaying: openNowPlaying,
                        onDock: onDock
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isVisible, dock == .bottom {
                    MiniPlayerOverlay(
                        isVisible: isVisible,
                        dock: .bottom,
                        openNowPlaying: openNowPlaying,
                        onDock: onDock
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
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
      MiniPlayerView(openNowPlaying: openNowPlaying)
        .simultaneousGesture(
          DragGesture(minimumDistance: 18, coordinateSpace: .local)
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
  @EnvironmentObject private var player: PlayerController
  let isVisible: Bool
  let edge: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onUndock: () -> Void

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
        .shadow(radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .simultaneousGesture(
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
          .onEnded { value in
            let returnsInward = edge == .leading
              ? value.translation.width > 35
              : value.translation.width < -35
            if returnsInward { onUndock() }
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
