import SwiftUI
import UIKit

@main
struct ResonanceApp: App {
    @UIApplicationDelegateAdaptor(ResonanceAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = LibraryStore()
    @StateObject private var player = PlayerController()
    @StateObject private var settings = AppSettings()
    @StateObject private var remoteLibrary = RemoteLibraryStore()
    @StateObject private var remoteDownloads = RemoteDownloadManager()
    @StateObject private var errorLog = AppErrorLog()

    init() {
        UIScrollView.appearance().bounces = false
        UIScrollView.appearance().alwaysBounceVertical = false
        ResonanceDiagnostics.shared.record("app.init")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(player)
                .environmentObject(player.progress)
                .environmentObject(settings)
                .environmentObject(remoteLibrary)
                .environmentObject(remoteDownloads)
                .environmentObject(errorLog)
                .tint(settings.accentColor)
                .preferredColorScheme(settings.colorScheme)
                .task(id: scenePhase) {
                    ResonanceDiagnostics.shared.record(
                        "scene.phase.task",
                        details: ["phase": String(describing: scenePhase)]
                    )
                    guard scenePhase == .active else { return }
                    ResonanceDiagnostics.shared.record("scene.active.refresh.begin")
                    async let localActivation: Void = library.refreshForActiveState()
                    async let remotePreparation: Void = {
                        await remoteLibrary.activateCachedCatalogAndCheckForChanges(using: settings)
                        await remoteLibrary.prewarmBrowseCache(
                            groupCompilationArtists: settings.groupCompilationArtists,
                            grouping: remoteLibrary.grouping
                        )
                    }()
                    await localActivation
                    await remotePreparation
                    remoteDownloads.resumePersistedDownloads(from: remoteLibrary.tracks, into: library)
                    ResonanceDiagnostics.shared.record("scene.active.refresh.end")
                }
        }
    }
}

@MainActor
final class ResonanceAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == RemoteBackgroundDownloadSession.sessionIdentifier else { return }
        RemoteBackgroundDownloadSession.shared.setBackgroundEventsCompletionHandler(completionHandler)
    }
}
