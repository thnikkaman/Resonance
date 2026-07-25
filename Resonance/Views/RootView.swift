import SwiftUI
import UIKit

enum AppTab: Hashable {
    case playing, library, streaming, settings
}

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var errorLog: AppErrorLog
    @State private var selectedTab: AppTab = .library

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    NowPlayingView(openLibrary: { selectedTab = .library })
                }
                .tabItem { Label("Playing", systemImage: "music.note") }
                .tag(AppTab.playing)

                NavigationStack { LibraryView() }
                    .tabItem { Label("Library", systemImage: "square.stack") }
                    .tag(AppTab.library)

                NavigationStack {
                    StreamingLibraryView(
                        openLibrary: { selectedTab = .library },
                        openSettings: { selectedTab = .settings }
                    )
                }
                    .tabItem { Label("Streaming", systemImage: "network") }
                    .tag(AppTab.streaming)

                NavigationStack { SettingsView(openLibrary: { selectedTab = .library }) }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MiniPlayerOverlay(isVisible: selectedTab != .playing) {
                    selectedTab = .playing
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }

            PlaybackCoordinatorView()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .foregroundStyle(settings.applyThemeColorToText ? settings.accentColor : Color.primary)
        .tint(settings.accentColor)
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

private struct MiniPlayerOverlay: View {
    @EnvironmentObject private var player: PlayerController
    let isVisible: Bool
    let openNowPlaying: () -> Void

    var body: some View {
        if isVisible, player.currentTrack != nil {
            MiniPlayerView(openNowPlaying: openNowPlaying)
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
