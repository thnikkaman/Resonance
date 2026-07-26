import SwiftUI

@main
struct ResonanceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = LibraryStore()
    @StateObject private var player = PlayerController()
    @StateObject private var settings = AppSettings()
    @StateObject private var remoteLibrary = RemoteLibraryStore()
    @StateObject private var remoteDownloads = RemoteDownloadManager()
    @StateObject private var errorLog = AppErrorLog()

    init() {
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
                    await library.refreshForActiveState()
                    await remoteLibrary.activateCachedCatalogAndCheckForChanges(using: settings)
                    ResonanceDiagnostics.shared.record("scene.active.refresh.end")
                }
        }
    }
}
