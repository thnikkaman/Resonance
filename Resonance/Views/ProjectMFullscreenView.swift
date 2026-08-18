import Foundation
import GLKit
import SwiftUI

final class ProjectMActivityCoordinator: @unchecked Sendable {
  static let shared = ProjectMActivityCoordinator()

  private let lock = NSLock()
  private var active = false

  var isActive: Bool {
    lock.withLock { active }
  }

  func setActive(_ active: Bool) {
    lock.withLock { self.active = active }
  }
}

private struct ResonanceProjectMPreset: Identifiable, Hashable, Sendable {
  let id: String
  let displayName: String
  let url: URL
  let isFocused: Bool
}

private actor ProjectMPresetCatalogStore {
  private var presets: [ResonanceProjectMPreset] = []
  private var didLoad = false

  func load(from projectMRoot: URL?) {
    guard !didLoad else { return }
    let focused = ProjectMFullscreenView.loadFocusedPresets(from: projectMRoot)
    let archive = ProjectMFullscreenView.archivePresets(from: projectMRoot)
    presets = focused + archive
    didLoad = true
  }

  func isReady() -> Bool {
    didLoad
  }

  func count() -> Int {
    presets.count
  }

  func allPresets() -> [ResonanceProjectMPreset] {
    presets
  }

  func nextPreset(
    after selectedID: String,
    offset: Int,
    banishedIDs: Set<String>,
    favoriteIDs: Set<String>,
    shuffle: Bool
  ) -> ResonanceProjectMPreset? {
    let choices = presets.filter { !banishedIDs.contains($0.id) }
    guard !choices.isEmpty else { return nil }

    if shuffle, offset > 0 {
      let candidates = choices.filter { $0.id != selectedID }
      guard !candidates.isEmpty else { return choices.first }
      let totalWeight = candidates.reduce(into: 0) { total, candidate in
        total += favoriteIDs.contains(candidate.id) ? 10 : 1
      }
      var roll = Int.random(in: 0..<max(totalWeight, 1))
      for candidate in candidates {
        let weight = favoriteIDs.contains(candidate.id) ? 10 : 1
        if roll < weight { return candidate }
        roll -= weight
      }
      return candidates.last
    }

    guard let currentIndex = choices.firstIndex(where: { $0.id == selectedID }) else {
      return choices.first
    }
    let nextIndex = (currentIndex + offset + choices.count) % choices.count
    return choices[nextIndex]
  }
}

struct ProjectMFullscreenView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var lyricsStore: LyricsStore
  @State private var presets: [ResonanceProjectMPreset] = []
  @State private var selectedArchivePreset: ResonanceProjectMPreset?
  @State private var presetCatalog = ProjectMPresetCatalogStore()
  @State private var fullCatalogReady = false
  @State private var presetAdvanceInFlight = false
  @AppStorage("resonance.projectmd.selectedPresetID") private var selectedID = ""
  @State private var isLoadingPresets = true
  @State private var controlsVisible = false
  @State private var rendererActive = false
  @State private var rendererGeneration = 0
  @State private var lowFPSBanishing = false
  @State private var displayedFPS: Int?
  @State private var showingPresetBrowser = false
  @State private var presetSearchText = ""
  @StateObject private var lyricsFeed = ProjectMLyricsFeed()
  @AppStorage("resonance.projectmd.favoritePresetIDs") private var favoriteIDsRaw = ""
  @AppStorage("resonance.projectmd.banishedPresetIDs") private var banishedIDsRaw = ""
  private let presetCycleTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  private var favoriteIDs: Set<String> {
    Set(favoriteIDsRaw.split(separator: ",").map(String.init))
  }

  private var banishedIDs: Set<String> {
    Set(banishedIDsRaw.split(separator: ",").map(String.init))
  }

  private var availablePresets: [ResonanceProjectMPreset] {
    var runtimePresets = presets
    if let selectedArchivePreset, !runtimePresets.contains(where: { $0.id == selectedArchivePreset.id }) {
      runtimePresets.append(selectedArchivePreset)
    }
    return runtimePresets.filter { !banishedIDs.contains($0.id) }
  }

  private var rotationPresets: [ResonanceProjectMPreset] {
    availablePresets.filter { $0.isFocused }
  }

  private var selectedPreset: ResonanceProjectMPreset? {
    availablePresets.first(where: { $0.id == selectedID }) ?? availablePresets.first
  }

  private var projectMRoot: URL? {
    Bundle.main.resourceURL?.appendingPathComponent("ProjectMD", isDirectory: true)
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let selectedPreset {
        ProjectMFullscreenGLView(
          preset: selectedPreset,
          isActive: rendererActive,
          lyricsEnabled: settings.projectMFullscreenLyricsEnabled,
          lyricsFeed: lyricsFeed,
          onFPSUpdate: { value in
            guard settings.showVisualizerFPSCounter else { return }
            displayedFPS = value
          },
          onSustainedLowFPS: { fps, duration in
            handleSustainedLowFPS(fps: fps, duration: duration)
          }
        )
          .equatable()
          .id(rendererGeneration)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.easeOut(duration: 0.22)) {
              controlsVisible.toggle()
            }
            ResonanceDiagnostics.shared.recordDeferredAlways(
              "projectm.controls.toggle",
              details: ["visible": String(controlsVisible)]
            )
          }
          .onTapGesture(count: 2) {
            dismiss()
          }
          .simultaneousGesture(
            DragGesture(minimumDistance: 30)
              .onEnded { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard abs(horizontal) >= 60, abs(horizontal) > vertical else { return }
                requestPresetAdvance(by: horizontal < 0 ? 1 : -1)
              }
          )
          .overlay {
            if controlsVisible {
              VStack {
                HStack {
                  fullscreenControl(title: "Exit", systemImage: "xmark") {
                    dismiss()
                  }
                  .accessibilityLabel("Exit visualizer")
                    .transition(.move(edge: .leading).combined(with: .opacity))
                  Spacer()
                  fullscreenControl(title: settings.projectMFullscreenLyricsEnabled ? "Lyrics On" : "Lyrics Off", systemImage: "text.quote") {
                    settings.projectMFullscreenLyricsEnabled.toggle()
                    ResonanceDiagnostics.shared.recordDeferredAlways(
                      "projectm.lyrics.toggle",
                      details: ["enabled": String(settings.projectMFullscreenLyricsEnabled)]
                    )
                  }
                  .transition(.move(edge: .leading).combined(with: .opacity))
                  Spacer()
                  fullscreenControl(
                    title: settings.projectMShufflePresets ? "Shuffle On" : "Shuffle Off",
                    systemImage: "shuffle"
                  ) {
                    settings.projectMShufflePresets.toggle()
                  }
                  .transition(.move(edge: .top).combined(with: .opacity))
                  Spacer()
                  fullscreenControl(
                    title: favoriteIDs.contains(selectedID) ? "Favorited" : "Favorite",
                    systemImage: favoriteIDs.contains(selectedID) ? "star.fill" : "star"
                  ) {
                    toggleFavorite()
                  }
                  .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                Spacer()
                VStack(spacing: 12) {
                  HStack {
                    fullscreenControl(title: "Browse", systemImage: "list.bullet") {
                      showingPresetBrowser = true
                      ResonanceDiagnostics.shared.recordDeferredAlways(
                        "projectm.preset.browser.open",
                        details: [
                          "catalog_count": "deferred",
                          "focused_count": String(rotationPresets.count),
                          "archive_mode": "staged",
                          "catalog_ready": String(fullCatalogReady)
                        ]
                      )
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    Spacer()
                    HStack(spacing: 16) {
                      ProjectMTransportButton(title: "Previous track", systemImage: "backward.fill", action: player.previous)
                      ProjectMPlaybackControl()
                      ProjectMTransportButton(title: "Next track", systemImage: "forward.fill", action: player.next)
                    }
                    Spacer()
                    fullscreenControl(title: "Banish", systemImage: "nosign") {
                      banishCurrentPreset()
                    }
                    .disabled(availablePresets.count <= 1)
                    .opacity(availablePresets.count > 1 ? 1 : 0.5)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                  }
                  ProjectMTrackSeekBar().frame(maxWidth: 430)
                }
              }
              .padding(.horizontal, 18)
              .padding(.vertical, 30)
              .animation(.easeOut(duration: 0.22), value: controlsVisible)
            }
          }
      } else if isLoadingPresets {
        ProgressView("Loading visualizations…")
          .tint(.white)
          .foregroundStyle(.white)
      } else {
        Text("No visualizations found in ProjectMD")
          .foregroundStyle(.white)
      }

      ProjectMLyricsFeedHost(feed: lyricsFeed, enabled: settings.projectMFullscreenLyricsEnabled)

      if settings.showVisualizerFPSCounter, let displayedFPS {
        Text("\(displayedFPS)")
          .font(.system(size: 18, weight: .medium, design: .monospaced))
          .foregroundStyle(.white)
          .padding(.top, 14)
          .padding(.trailing, 16)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .allowsHitTesting(false)
          .accessibilityLabel("Visualizer frames per second")
      }

      ProjectMDownloadFlushOnDisappear()
    }
    .sheet(isPresented: $showingPresetBrowser) {
      ProjectMPresetBrowser(
        focusedPresets: availablePresets.filter(\.isFocused),
        catalog: presetCatalog,
        projectMRoot: projectMRoot,
        selectedID: $selectedID,
        searchText: $presetSearchText,
        onSelect: { preset in
          selectedArchivePreset = preset.isFocused ? nil : preset
          selectedID = preset.id
        }
      )
    }
    .statusBarHidden(true)
    .interactiveDismissDisabled()
    .onAppear {
      ResonanceOrientationCoordinator.shared.setFullscreenEnabled(true)
      ProjectMActivityCoordinator.shared.setActive(true)
      rendererActive = scenePhase == .active
      UIApplication.shared.isIdleTimerDisabled = settings.projectMFullscreenLyricsEnabled && rendererActive
    }
    .task(id: [
      player.currentTrack?.id.uuidString ?? "none",
      settings.lyricsProviderConfiguration?.cacheKey ?? "none"
    ].joined(separator: ":")) {
      // The fullscreen cover can become the first active lyrics consumer.
      // Refresh here so opening the visualizer never depends on the parent
      // Now Playing task having completed first.
      lyricsStore.load(
        for: player.currentTrack,
        provider: settings.lyricsProviderConfiguration,
        searchLocalSiblingFile: true
      )
    }
    .onDisappear {
      ResonanceOrientationCoordinator.shared.setFullscreenEnabled(false)
      ProjectMActivityCoordinator.shared.setActive(false)
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .onChange(of: scenePhase) { _, phase in
      // A CADisplayLink can remain retained while a full-screen cover is
      // inactive (phone lock, app switcher, or a scene transition). Tear down
      // the native renderer so it cannot keep consuming GPU/CPU and audio
      // staging work while no frame can be presented.
      rendererActive = phase == .active
      UIApplication.shared.isIdleTimerDisabled = settings.projectMFullscreenLyricsEnabled && rendererActive
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.scene.renderer",
        details: ["phase": String(describing: phase), "active": String(phase == .active)]
      )
    }
    .onChange(of: showingPresetBrowser) { _, showing in
      // The live OpenGL renderer does not need to compete with the archive
      // browser. The browser owns its catalog and can load it lazily while
      // the renderer is fully quiescent.
      rendererActive = scenePhase == .active && !showing
    }
    .onChange(of: settings.projectMFullscreenLyricsEnabled) { _, enabled in
      UIApplication.shared.isIdleTimerDisabled = enabled && rendererActive && scenePhase == .active
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.idle_timer",
        details: ["disabled": String(enabled && rendererActive && scenePhase == .active)]
      )
    }
    .onChange(of: settings.showVisualizerFPSCounter) { _, enabled in
      if !enabled { displayedFPS = nil }
    }
    .onReceive(presetCycleTimer) { _ in
      guard scenePhase == .active,
            settings.projectMAutoCyclePresets,
            !isLoadingPresets,
            fullCatalogReady,
            !availablePresets.isEmpty
      else { return }
      requestPresetAdvance(by: 1)
    }
    .task {
      if !settings.projectMDefaultsConfigured {
        // Resonance did not previously expose these fullscreen options. Make
        // the first integrated experience match ProjectMD's default behavior,
        // while preserving any later user choice.
        settings.projectMShufflePresets = true
        settings.projectMAutoCyclePresets = true
        settings.projectMDefaultsConfigured = true
      }
      let root = projectMRoot
      if presets.isEmpty {
        let loaded = await Task.detached(priority: .utility) {
          Self.loadFocusedPresets(from: root)
        }.value
        presets = loaded.filter { !banishedIDs.contains($0.id) }
        if let selectedArchive = Self.archivePreset(for: selectedID, from: root),
           !banishedIDs.contains(selectedArchive.id) {
          selectedArchivePreset = selectedArchive
        } else if !presets.contains(where: { $0.id == selectedID && $0.isFocused }) {
          selectedID = presets.first(where: { $0.isFocused })?.id ?? presets.first?.id ?? ""
        }
        isLoadingPresets = false
      }

      await presetCatalog.load(from: root)
      guard !Task.isCancelled else { return }
      fullCatalogReady = await presetCatalog.isReady()
      let catalogCount = await presetCatalog.count()
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.preset.catalog.loaded",
        details: [
          "catalog_count": String(catalogCount),
          "focused_count": String(presets.count),
          "mode": "staged"
        ]
      )
    }
  }

  private func fullscreenControl(
    title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay { Capsule().stroke(Color.black, lineWidth: 3) }
        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }

  private func toggleFavorite() {
    guard let selectedPreset else { return }
    var updated = favoriteIDs
    if updated.contains(selectedPreset.id) {
      updated.remove(selectedPreset.id)
    } else {
      updated.insert(selectedPreset.id)
    }
    favoriteIDsRaw = updated.sorted().joined(separator: ",")
    ResonanceDiagnostics.shared.recordDeferredAlways(
      "projectm.preset.favorite",
      details: [
        "preset_hash": String(selectedPreset.id.hashValue),
        "enabled": String(updated.contains(selectedPreset.id))
      ]
    )
  }

  private func banishCurrentPreset(nextChoices: [ResonanceProjectMPreset]? = nil) {
    guard let selectedPreset, availablePresets.count > 1 else { return }
    let remaining = availablePresets.filter { $0.id != selectedPreset.id }
    let preferred = (nextChoices ?? availablePresets).filter { $0.id != selectedPreset.id }
    guard let next = nextPreset(from: preferred) ?? remaining.first else { return }
    let oldID = selectedPreset.id
    var updated = banishedIDs
    updated.insert(oldID)
    banishedIDsRaw = updated.sorted().joined(separator: ",")
    selectedID = next.id
    controlsVisible = false
    ResonanceDiagnostics.shared.recordDeferredAlways(
      "projectm.preset.banished",
      details: [
        "preset_hash": String(oldID.hashValue),
        "next_hash": String(next.id.hashValue)
      ]
    )
  }

  private func nextPreset(from choices: [ResonanceProjectMPreset]) -> ResonanceProjectMPreset? {
    guard !choices.isEmpty else { return nil }
    if settings.projectMShufflePresets {
      var weighted: [ResonanceProjectMPreset] = []
      weighted.reserveCapacity(choices.count * 2)
      for choice in choices {
        weighted.append(contentsOf: Array(
          repeating: choice,
          count: favoriteIDs.contains(choice.id) ? 10 : 1
        ))
      }
      return weighted.randomElement()
    }
    return choices.first
  }

  private func handleSustainedLowFPS(fps: Double, duration: TimeInterval) {
    guard !lowFPSBanishing, availablePresets.count > 1 else { return }
    lowFPSBanishing = true
    guard let selectedPreset else {
      lowFPSBanishing = false
      return
    }
    ResonanceDiagnostics.shared.recordDeferredAlways(
      "projectm.preset.auto_banished",
      details: [
        "preset_hash": String(selectedPreset.id.hashValue),
        "fps": String(format: "%.1f", fps),
        "duration_seconds": String(format: "%.1f", duration)
      ]
    )
    if settings.visualizerTelemetryEnabled {
      let telemetryID = selectedPreset.id
      Task.detached(priority: .utility) {
        await VisualizerTelemetryService.shared.enqueueLowFramerateBanish(
          visualizationID: telemetryID,
          measuredFPS: fps
        )
      }
    }
    banishCurrentPreset(nextChoices: rotationPresets)
    lowFPSBanishing = false
  }

  private func requestPresetAdvance(by offset: Int) {
    guard fullCatalogReady, !presetAdvanceInFlight else { return }
    presetAdvanceInFlight = true
    let catalog = presetCatalog
    let currentID = selectedID
    let favorites = favoriteIDs
    let banished = banishedIDs
    let shuffle = settings.projectMShufflePresets
    Task { [catalog] in
      let next = await catalog.nextPreset(
        after: currentID,
        offset: offset,
        banishedIDs: banished,
        favoriteIDs: favorites,
        shuffle: shuffle
      )
      guard !Task.isCancelled else {
        presetAdvanceInFlight = false
        return
      }
      guard scenePhase == .active else {
        presetAdvanceInFlight = false
        return
      }
      if let next {
        selectedArchivePreset = next.isFocused ? nil : next
        selectedID = next.id
        ResonanceDiagnostics.shared.recordDeferredAlways(
          "projectm.preset.cycle",
          details: [
            "catalog": next.isFocused ? "focused" : "archive",
            "offset": String(offset),
            "shuffle": String(shuffle)
          ]
        )
      }
      presetAdvanceInFlight = false
    }
  }

  nonisolated fileprivate static func loadFocusedPresets(from projectMRoot: URL?) -> [ResonanceProjectMPreset] {
    guard let projectMRoot, FileManager.default.fileExists(atPath: projectMRoot.path) else { return [] }

    // Keep the exact visible startup set and ordering used by ProjectMD. The
    // alphabetically first CreamOfTheCrop entries are transition-effect assets
    // whose intended output is black; they are not suitable startup presets.
    let verifiedFixtures: [(resourceName: String, displayName: String)] = [
      ("MilkDrop2077.034 The Escargot 006f", "Escargot 006f · wavecode + shapes"),
      ("MilkDrop2077.040 Sand Rose 3", "Sand Rose 3 · sprite"),
      ("MilkDrop2077.040 Sand Rose 7 BLACK", "Sand Rose 7 BLACK · sprite + shader"),
      ("martin - the early universe - Milkdrop2077 ring5", "Early Universe Ring5 · sprite"),
      ("MilkDrop2077 + bdrv + flexi - the glass bead game 004", "Glass Bead Game 004 · sprite"),
      ("martin - harmony of colours MilkDrop2077 rmx3", "Harmony of Colours rmx3 · sprite"),
      ("martin - space debris", "Space Debris · textured shapes"),
      ("MilkDrop2077.026 My Little Forest 001 Green", "My Little Forest · textured shapes"),
      ("MilkDrop2077 vs martin + Stahlregen + Sprite", "Stahlregen Sprite · sprite"),
      ("MilkDrop2077.R194", "R194 · shape equations")
    ]
    let focusedRoot = projectMRoot.appendingPathComponent("MilkDrop3Test/presets", isDirectory: true)
    let focusedPresets = verifiedFixtures.compactMap { fixture -> ResonanceProjectMPreset? in
      let url = focusedRoot.appendingPathComponent(fixture.resourceName).appendingPathExtension("milk")
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      return ResonanceProjectMPreset(
        id: "resonance.projectmd.milkdrop3.\(fixture.resourceName)",
        displayName: fixture.displayName,
        url: url,
        isFocused: true
      )
    }

    return focusedPresets
  }

  nonisolated private static func archivePreset(
    for id: String,
    from projectMRoot: URL?
  ) -> ResonanceProjectMPreset? {
    let prefix = "resonance.projectm.cream-of-the-crop."
    guard let projectMRoot,
          id.hasPrefix(prefix)
    else { return nil }
    let relativePath = String(id.dropFirst(prefix.count))
    guard !relativePath.isEmpty,
          !relativePath.contains("..")
    else { return nil }
    let archiveRoot = projectMRoot.appendingPathComponent("CreamOfTheCrop", isDirectory: true)
    let url = archiveRoot.appendingPathComponent(relativePath)
    guard url.pathExtension.caseInsensitiveCompare("milk") == .orderedSame,
          FileManager.default.fileExists(atPath: url.path),
          (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    else { return nil }
    return archivePreset(url: url, relativePath: relativePath)
  }

  nonisolated fileprivate static func archivePresets(from projectMRoot: URL?) -> [ResonanceProjectMPreset] {
    guard let projectMRoot else { return [] }
    let archiveRoot = projectMRoot.appendingPathComponent("CreamOfTheCrop", isDirectory: true)
    guard FileManager.default.fileExists(atPath: archiveRoot.path) else { return [] }
    let rootPath = archiveRoot.path.hasSuffix("/") ? archiveRoot.path : archiveRoot.path + "/"
    let archiveURLs = FileManager.default.enumerator(
      at: archiveRoot,
      includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )?.compactMap { $0 as? URL }.filter { url in
      guard url.pathExtension.caseInsensitiveCompare("milk") == .orderedSame else { return false }
      return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } ?? []

    return archiveURLs.map { url in
      let relativePath = String(url.path.dropFirst(rootPath.count))
      return archivePreset(url: url, relativePath: relativePath)
    }
  }

  nonisolated private static func archivePreset(url: URL, relativePath: String) -> ResonanceProjectMPreset {
    let components = relativePath.split(separator: "/").map(String.init)
    let filename = url.deletingPathExtension().lastPathComponent
    let category = components.dropLast().joined(separator: " / ")
    return ResonanceProjectMPreset(
      id: "resonance.projectm.cream-of-the-crop.\(relativePath)",
      displayName: category.isEmpty ? filename : "\(category) · \(filename)",
      url: url,
      isFocused: false
    )
  }
}

private struct ProjectMPresetBrowser: View {
  @Environment(\.dismiss) private var dismiss
  let focusedPresets: [ResonanceProjectMPreset]
  let catalog: ProjectMPresetCatalogStore
  let projectMRoot: URL?
  @Binding var selectedID: String
  @Binding var searchText: String
  let onSelect: (ResonanceProjectMPreset) -> Void
  @State private var archivePresets: [ResonanceProjectMPreset] = []
  @State private var isLoadingArchive = true

  private var presets: [ResonanceProjectMPreset] {
    focusedPresets + archivePresets
  }

  private var filteredPresets: [ResonanceProjectMPreset] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return presets }
    return presets.filter { preset in
      preset.displayName.localizedCaseInsensitiveContains(query)
    }
  }

  private var filteredFocusedPresets: [ResonanceProjectMPreset] {
    filteredPresets.filter { $0.isFocused }
  }

  private var filteredArchivePresets: [ResonanceProjectMPreset] {
    filteredPresets.filter { !$0.isFocused }
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(isLoadingArchive
               ? "The focused set is ready. Loading the full catalog…"
               : "\(presets.count) visualizations available. Automatic rotation loads one preset at a time; archive entries use hard cuts.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if !filteredFocusedPresets.isEmpty {
          Section("Focused smooth set") {
            ForEach(filteredFocusedPresets) { presetRow($0) }
          }
        }

        if !filteredArchivePresets.isEmpty {
          Section("Cream of the Crop catalog") {
            ForEach(filteredArchivePresets) { presetRow($0) }
          }
        }
      }
      .listStyle(.insetGrouped)
      .searchable(text: $searchText, prompt: "Search visualizations")
      .navigationTitle("Visualizations")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .task {
      await catalog.load(from: projectMRoot)
      let loaded = await catalog.allPresets()
      guard !Task.isCancelled else { return }
      archivePresets = loaded.filter { !$0.isFocused }
      isLoadingArchive = false
    }
  }

  @ViewBuilder
  private func presetRow(_ preset: ResonanceProjectMPreset) -> some View {
    Button {
      selectedID = preset.id
      onSelect(preset)
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.preset.browser.select",
        details: [
          "preset_hash": String(preset.id.hashValue),
          "catalog": preset.isFocused ? "focused" : "archive"
        ]
      )
      dismiss()
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(preset.displayName)
            .font(.system(size: 9))
            .foregroundStyle(.primary)
            .lineLimit(4)
            .minimumScaleFactor(0.5)
          if !preset.isFocused {
            Text("Archive preset · hard cut")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 8)
        if preset.id == selectedID {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(preset.displayName)
    .accessibilityValue(preset.id == selectedID ? "Selected" : "")
  }
}

private struct ProjectMPlaybackControl: View {
  @EnvironmentObject private var player: PlayerController

  var body: some View {
    Button {
      let willPlay = !player.isPlaying
      player.toggle()
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.playback.toggle",
        details: ["playing": String(willPlay)]
      )
    } label: {
      Label(
        player.isPlaying ? "Pause" : "Play",
        systemImage: player.isPlaying ? "pause.fill" : "play.fill"
      )
      .font(.headline.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.black.opacity(0.72), in: Capsule())
      .overlay { Capsule().stroke(Color.black, lineWidth: 3) }
      .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 2)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(player.isPlaying ? "Pause music" : "Play music")
  }
}

private struct ProjectMTransportButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 46, height: 42)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay { Capsule().stroke(Color.black, lineWidth: 3) }
        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 2)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

private struct ProjectMTrackSeekBar: View {
  @EnvironmentObject private var player: PlayerController
  @State private var position = 0.0
  @State private var isEditing = false

  private var range: ClosedRange<Double> { 0...max(player.duration, 0.001) }

  var body: some View {
    VStack(spacing: 3) {
      Slider(value: $position, in: range, onEditingChanged: { editing in
        isEditing = editing
        if editing {
          position = min(max(player.elapsed, range.lowerBound), range.upperBound)
        } else {
          player.seek(to: position)
        }
      })
      .tint(.white)
      .accessibilityLabel("Track position")

      HStack {
        Text(format(position))
        Spacer()
        Text(format(player.duration))
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.white.opacity(0.9))
    }
    .onAppear { position = player.elapsed }
    .onChange(of: player.elapsed) { _, value in
      if !isEditing { position = value }
    }
    .onChange(of: player.currentTrack?.id) { _, _ in position = player.elapsed }
  }

  private func format(_ value: Double) -> String {
    let total = max(0, Int(value.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}

@MainActor
private final class ProjectMLyricsFeed: ObservableObject {
  struct Snapshot {
    let key: String
    let text: String
    let progress: Float
  }

  private var trackKey = ""
  private var trackTitle = ""
  private var trackDuration: TimeInterval = 0
  private let titleDisplayDuration: TimeInterval = 5
  private var document: LyricsDocument?
  private var elapsed: TimeInterval = 0
  private var elapsedAnchorMediaTime = CACurrentMediaTime()
  private var isPlaying = false
  private var enabled = false

  func updateTrack(_ track: Track?) {
    let nextKey = track?.id.uuidString ?? ""
    trackTitle = track?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard nextKey != trackKey else {
      trackDuration = track?.duration ?? 0
      return
    }
    trackKey = nextKey
    trackDuration = track?.duration ?? 0
    document = nil
    elapsed = 0
    elapsedAnchorMediaTime = CACurrentMediaTime()
  }

  func update(document: LyricsDocument?) {
    self.document = document
  }

  func update(elapsed: TimeInterval) {
    self.elapsed = elapsed
    elapsedAnchorMediaTime = CACurrentMediaTime()
  }

  func update(isPlaying: Bool) {
    self.isPlaying = isPlaying
    elapsedAnchorMediaTime = CACurrentMediaTime()
  }

  func update(enabled: Bool) {
    self.enabled = enabled
  }

  func snapshot() -> Snapshot? {
    let currentElapsed = isPlaying
      ? elapsed + max(0, CACurrentMediaTime() - elapsedAnchorMediaTime)
      : elapsed
    guard enabled, !trackKey.isEmpty else { return nil }

    // Give the native lyric renderer an immediate opening cue. This provides
    // useful context while a lyric document is absent or its first synced line
    // has not started yet, but yields immediately when lyrics begin. If no
    // lyric starts promptly, the title uses the same five-second timeout as a
    // lyric line with no timely successor.
    let firstLyricStart = document?.syncedLines.first?.startTime
    let titleEndTime = min(titleDisplayDuration, max(0, firstLyricStart ?? .greatestFiniteMagnitude))
    if currentElapsed < titleEndTime, !trackTitle.isEmpty {
      let progress = Float(min(1, max(0, currentElapsed / max(0.8, titleEndTime))))
      return Snapshot(
        key: "\(trackKey):title",
        text: trackTitle,
        progress: progress
      )
    }

    guard let lines = document?.syncedLines,
          !lines.isEmpty,
          currentElapsed >= lines[0].startTime
    else { return nil }

    var low = 0
    var high = lines.count
    while low < high {
      let middle = (low + high) / 2
      if lines[middle].startTime <= currentElapsed {
        low = middle + 1
      } else {
        high = middle
      }
    }
    let index = max(0, min(lines.count - 1, low - 1))
    let line = lines[index]
    let nextStart = index + 1 < lines.count ? lines[index + 1].startTime : nil
    // Keep a line visible for its normal interval when the next line arrives
    // promptly. If the next line is delayed or absent, let MilkDrop's
    // progress-driven text animation fade it out after five seconds instead
    // of holding the last lyric until the end of the track.
    let timeoutStart = line.startTime + 5
    let endTime: TimeInterval
    if let nextStart, nextStart <= timeoutStart {
      endTime = nextStart
    } else {
      endTime = timeoutStart + 0.75
    }
    guard currentElapsed < endTime else { return nil }
    let duration = max(0.8, endTime - line.startTime)
    let progress = Float(min(1, max(0, (currentElapsed - line.startTime) / duration)))
    return Snapshot(
      key: "\(trackKey):\(line.id)",
      text: line.text,
      progress: progress
    )
  }
}

private struct ProjectMLyricsFeedHost: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var lyricsStore: LyricsStore
  let feed: ProjectMLyricsFeed
  let enabled: Bool
  private let elapsedTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .onAppear {
        feed.updateTrack(player.currentTrack)
        feed.update(document: lyricsStore.document)
        feed.update(elapsed: player.elapsed)
        feed.update(isPlaying: player.isPlaying)
        feed.update(enabled: enabled)
      }
      .onChange(of: enabled) { _, value in
        feed.update(enabled: value)
      }
      .onChange(of: player.currentTrack?.id) { _, _ in
        feed.updateTrack(player.currentTrack)
      }
      .onChange(of: player.isPlaying) { _, value in
        feed.update(isPlaying: value)
      }
      // Do not observe PlaybackProgress here. It publishes every 120 ms and
      // invalidates this fullscreen SwiftUI subtree while the renderer's
      // CADisplayLink is also running on the main run loop. The lyric feed
      // interpolates between these lower-rate anchors, so the visual lyric
      // animation remains smooth without making controls and preset changes
      // compete with a high-frequency SwiftUI update.
      .onReceive(elapsedTimer) { _ in
        feed.update(elapsed: player.elapsed)
      }
      .onReceive(lyricsStore.$document) { document in
        feed.update(document: document)
      }
  }
}

private struct ProjectMDownloadFlushOnDisappear: View {
  @EnvironmentObject private var downloads: RemoteDownloadManager

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .onDisappear {
        downloads.flushDeferredLibraryRefreshes()
      }
  }
}

private struct ProjectMFullscreenGLView: UIViewRepresentable, Equatable {
  let preset: ResonanceProjectMPreset
  let isActive: Bool
  let lyricsEnabled: Bool
  let lyricsFeed: ProjectMLyricsFeed
  let onFPSUpdate: @MainActor (Int?) -> Void
  let onSustainedLowFPS: @MainActor (Double, TimeInterval) -> Void

  nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.preset.id == rhs.preset.id &&
      lhs.isActive == rhs.isActive &&
      lhs.lyricsEnabled == rhs.lyricsEnabled
  }

  @MainActor
  final class Coordinator: NSObject, @preconcurrency GLKViewDelegate {
    // The fullscreen renderer shares the main run loop with SwiftUI controls.
    // The device log showed 23–26 ms frames at 0.75 scale and pathological
    // presets reaching 183–400 ms. A fixed half-resolution drawable keeps
    // ProjectM's expensive pixel work bounded without reallocating the
    // drawable during interaction.
    private let maximumDrawableScale: CGFloat = 0.5
    private var bridge: OpaquePointer?
    private weak var view: GLKView?
    private var displayLink: CADisplayLink?
    private var loadedPresetID = ""
    private var loadedPresetWasFocused = false
    private var lastDrawableSize = CGSize.zero
    private var targetFramebuffer: UInt32?
    private var lastPresetChangeAt: CFTimeInterval?
    private var displayTickCount = 0
    private var lyricsFeed: ProjectMLyricsFeed?
    private var activeLyricKey: String?
    private var pendingLyricKey: String?
    private var preparingLyricKey: String?
    private var preparedLyricKey: String?
    private var preparedLyricAddress: UInt?
    private var lyricPreparationTask: Task<Void, Never>?
    private var lyricPreparationGeneration: UInt = 0
    private var lyricsEnabled = false
    private var lastFrameStart = 0.0
    private var timingIntervals = 0
    private var timingElapsed = 0.0
    private var measuredFPS: Double?
    private var lowPerformanceSince: CFTimeInterval?
    private var lowPerformanceTriggered = false
    private var lowPerformanceEligibleAt = 0.0
    private var lowFPSCallback: (@MainActor (Double, TimeInterval) -> Void)?
    private var fpsCallback: (@MainActor (Int?) -> Void)?
    private var fpsWindowStart: CFTimeInterval?
    private var fpsWindowFrames = 0
    private var renderMetricFrames = 0
    private var renderMetricTotal = 0.0
    private var renderMetricMaximum = 0.0
    private var frameGapMaximum = 0.0
    private var frameGapsOver33ms = 0
    private var frameGapsOver50ms = 0

    func makeView(
      _ view: GLKView,
      initialPreset: ResonanceProjectMPreset,
      isActive: Bool,
      lyricsEnabled: Bool,
      lyricsFeed: ProjectMLyricsFeed,
      onFPSUpdate: @escaping @MainActor (Int?) -> Void,
      onSustainedLowFPS: @escaping @MainActor (Double, TimeInterval) -> Void
    ) {
      self.view = view
      self.fpsCallback = onFPSUpdate
      self.lowFPSCallback = onSustainedLowFPS
      self.lyricsEnabled = lyricsEnabled
      self.lyricsFeed = lyricsFeed
      ResonanceDiagnostics.shared.record(
        "projectm.view.created",
        details: ["context": "opengles3"]
      )
      // Match ProjectMD's native lifecycle: establish the EAGL context and
      // finish the initial ProjectM setup before starting the display link.
      // Starting display callbacks while the preset is still being loaded can
      // interleave GLKView presentation with ProjectM framebuffer creation.
      view.contentScaleFactor = (view.window?.screen.scale ?? UIScreen.main.scale) * maximumDrawableScale
      setActive(isActive, preset: initialPreset)
    }

    func setActive(_ isActive: Bool, preset: ResonanceProjectMPreset) {
      if isActive {
        guard bridge == nil, let view else { return }
        ResonanceDiagnostics.shared.recordDeferredAlways(
          "projectm.display.start",
          details: ["reason": "active"]
        )
        EAGLContext.setCurrent(view.context)
        bridge = resonance_native_projectm_create()
        loadedPresetID = ""
        loadedPresetWasFocused = false
        update(preset: preset)
        let link = CADisplayLink(target: self, selector: #selector(displayTick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
      } else {
        guard bridge != nil || displayLink != nil else { return }
        ResonanceDiagnostics.shared.recordDeferredAlways(
          "projectm.display.stop",
          details: ["reason": "inactive"]
        )
        displayLink?.invalidate()
        displayLink = nil
        if let bridge {
          resonance_native_projectm_destroy(bridge)
        }
        bridge = nil
        loadedPresetWasFocused = false
        lastDrawableSize = .zero
        targetFramebuffer = nil
        lastFrameStart = 0
        timingIntervals = 0
        timingElapsed = 0
        measuredFPS = nil
        lowPerformanceSince = nil
        lowPerformanceTriggered = false
        lowPerformanceEligibleAt = 0
        resetFPSCounter(notify: true)
        resetLyricState()
      }
    }

    func setLowFPSCallback(_ callback: @escaping @MainActor (Double, TimeInterval) -> Void) {
      lowFPSCallback = callback
    }

    func setFPSCallback(_ callback: @escaping @MainActor (Int?) -> Void) {
      fpsCallback = callback
    }

    func setLyrics(enabled: Bool, feed: ProjectMLyricsFeed) {
      guard lyricsEnabled != enabled || lyricsFeed !== feed else { return }
      lyricsEnabled = enabled
      lyricsFeed = feed
      feed.update(enabled: enabled)
    }

    func update(preset: ResonanceProjectMPreset) {
      guard loadedPresetID != preset.id else { return }
      // Archive entries remain available for explicit inspection, but their
      // one-time native setup must not add a second live renderer during a
      // transition. The focused set keeps the smooth transition behavior.
      let smooth = !loadedPresetID.isEmpty && loadedPresetWasFocused && preset.isFocused
      loadedPresetID = preset.id
      loadedPresetWasFocused = preset.isFocused
      lastPresetChangeAt = CACurrentMediaTime()
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.preset.transition.begin",
        details: [
          "smooth": String(smooth),
          "preset_hash": String(preset.id.hashValue)
        ]
      )
      lowPerformanceSince = nil
      lowPerformanceTriggered = false
      // Do not classify the intentional preset transition as a failed preset.
      lowPerformanceEligibleAt = CACurrentMediaTime() + 1.5
      resetFPSCounter(notify: true)
      let projectMRoot = Bundle.main.resourceURL?.appendingPathComponent(
        "ProjectMD",
        isDirectory: true
      )
      let textureRoot = projectMRoot?.appendingPathComponent(
        "MilkDrop3Test",
        isDirectory: true
      )
      let bundledTextureRoot = projectMRoot?.appendingPathComponent("MilkDrop3Test/textures", isDirectory: true)
      let bundledSpritesRoot = projectMRoot?.appendingPathComponent("MilkDrop3Test/sprites", isDirectory: true)
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.resource.paths",
        details: [
          "preset": preset.url.lastPathComponent,
          "transition_asset": preset.url.path.contains("/! Transition/") ? "true" : "false",
          "preset_exists": FileManager.default.fileExists(atPath: preset.url.path) ? "true" : "false",
          "texture_root_exists": bundledTextureRoot.map { FileManager.default.fileExists(atPath: $0.path) ? "true" : "false" } ?? "false",
          "sprite_root_exists": bundledSpritesRoot.map { FileManager.default.fileExists(atPath: $0.path) ? "true" : "false" } ?? "false"
        ]
      )
      guard let bridge, resonance_native_projectm_is_ready(bridge) else { return }
      let primaryPath = bundledTextureRoot?.path ?? textureRoot?.path ?? preset.url.deletingLastPathComponent().path
      let secondaryPath = bundledSpritesRoot?.path
      primaryPath.withCString { primary in
        if let secondaryPath {
          secondaryPath.withCString { secondary in
            resonance_native_projectm_set_texture_paths(bridge, primary, secondary)
          }
        } else {
          resonance_native_projectm_set_texture_paths(bridge, primary, nil)
        }
      }
      pathLoad(preset.url.path, bridge: bridge, smooth: smooth)
    }

    private func pathLoad(_ path: String, bridge: OpaquePointer, smooth: Bool) {
      path.withCString { pathPointer in
        _ = resonance_native_projectm_load_preset_file(bridge, pathPointer, smooth)
      }
    }

    func resize(width: UInt, height: UInt) {
      if let bridge, resonance_native_projectm_is_ready(bridge) {
        resonance_native_projectm_set_window_size(bridge, Int(width), Int(height))
      }
    }

    func glkView(_ view: GLKView, drawIn rect: CGRect) {
      // GLKView does not guarantee that its EAGL context is current when the
      // delegate is entered. ProjectMD explicitly establishes it before
      // inspecting or changing the drawable framebuffer.
      EAGLContext.setCurrent(view.context)
      guard let bridge, resonance_native_projectm_is_ready(bridge) else { return }
      let frameStart = CACurrentMediaTime()
      if fpsWindowStart == nil {
        fpsWindowStart = frameStart
      }
      fpsWindowFrames += 1
      if let fpsWindowStart,
         frameStart - fpsWindowStart >= 1 {
        let fps = Double(fpsWindowFrames) / (frameStart - fpsWindowStart)
        fpsCallback?(Int(fps.rounded()))
        self.fpsWindowStart = frameStart
        fpsWindowFrames = 0
      }
      if lastFrameStart > 0 {
        let interval = frameStart - lastFrameStart
        if interval > 0, interval < 0.5 {
          frameGapMaximum = max(frameGapMaximum, interval)
          if interval >= (1.0 / 30.0) { frameGapsOver33ms += 1 }
          if interval >= 0.05 { frameGapsOver50ms += 1 }
          if interval >= 0.1 {
            ResonanceDiagnostics.shared.recordDeferredAlways(
              "projectm.frame.stall",
              details: [
                "gap_ms": String(format: "%.1f", interval * 1000),
                "preset_hash": String(loadedPresetID.hashValue),
                "since_preset_change_ms": lastPresetChangeAt.map {
                  String(format: "%.1f", (frameStart - $0) * 1000)
                } ?? "unknown"
              ]
            )
          }
          timingIntervals += 1
          timingElapsed += interval
          if timingIntervals >= 15 {
            measuredFPS = timingElapsed > 0 ? Double(timingIntervals) / timingElapsed : nil
            timingIntervals = 0
            timingElapsed = 0
            evaluateLowPerformance(at: frameStart)
          }
        } else {
          timingIntervals = 0
          timingElapsed = 0
        }
      }
      lastFrameStart = frameStart
      let drawableSize = CGSize(width: view.drawableWidth, height: view.drawableHeight)
      let drawableResized = drawableSize != lastDrawableSize
      if drawableResized {
        lastDrawableSize = drawableSize
        resonance_native_projectm_set_window_size(
          bridge,
          Int(view.drawableWidth),
          Int(view.drawableHeight)
        )
      }
      // GLKView can recreate its drawable framebuffer when SwiftUI changes
      // the surrounding hierarchy, even when the drawable size is unchanged.
      // Controls, favorites, and preset transitions all cause those updates.
      // Reacquire the framebuffer while GLKView's draw callback has made the
      // current drawable active; retaining an ID across callbacks can point
      // ProjectM at a stale FBO and produce GL_INVALID_FRAMEBUFFER_OPERATION.
      var framebuffer: GLint = 0
      glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &framebuffer)
      let resolved = UInt32(max(framebuffer, 0))
      targetFramebuffer = resolved
      resonance_native_projectm_set_target_framebuffer(bridge, resolved)
      prepareNativeLyric(bridge: bridge)
      resonance_native_projectm_render(bridge)
      installPendingLyric(bridge: bridge)
      recordRenderMetric(CACurrentMediaTime() - frameStart)
    }

    private func evaluateLowPerformance(at now: CFTimeInterval) {
      guard now >= lowPerformanceEligibleAt, let measuredFPS, measuredFPS > 0 else { return }
      guard measuredFPS < 30 else {
        lowPerformanceSince = nil
        lowPerformanceTriggered = false
        return
      }
      if lowPerformanceSince == nil {
        lowPerformanceSince = now
        return
      }
      guard let lowPerformanceSince,
            !lowPerformanceTriggered,
            now - lowPerformanceSince >= 5 else { return }
      lowPerformanceTriggered = true
      lowFPSCallback?(measuredFPS, now - lowPerformanceSince)
    }

    @objc private func displayTick() {
      if displayTickCount < 3 {
        displayTickCount += 1
        ResonanceDiagnostics.shared.record(
          "projectm.display.tick",
          details: ["count": String(displayTickCount)]
        )
      }
      guard let view, let window = view.window, !view.isHidden, view.alpha > 0 else { return }
      guard view.convert(view.bounds, to: window).intersects(window.bounds) else { return }
      view.display()
    }

    private func prepareNativeLyric(bridge: OpaquePointer) {
      guard lyricsEnabled, let snapshot = lyricsFeed?.snapshot() else {
        if activeLyricKey != nil || pendingLyricKey != nil || preparedLyricAddress != nil {
          resonance_native_projectm_clear_lyric(bridge)
          resetLyricState()
        }
        return
      }

      if activeLyricKey == nil {
        ensurePrepared(snapshot)
        if preparedLyricKey == snapshot.key {
          applyPreparedLyric(snapshot, bridge: bridge)
        }
      } else if activeLyricKey != snapshot.key {
        ensurePrepared(snapshot)
        if preparedLyricKey == snapshot.key {
          // Render one completion frame first. ProjectM burns the old line into
          // feedback at progress 1; the prepared next line is uploaded after it.
          resonance_native_projectm_set_lyric_progress(bridge, 1)
          pendingLyricKey = snapshot.key
        }
      } else {
        resonance_native_projectm_set_lyric_progress(bridge, snapshot.progress)
      }
    }

    private func installPendingLyric(bridge: OpaquePointer) {
      guard let pendingLyricKey,
            let snapshot = lyricsFeed?.snapshot(),
            snapshot.key == pendingLyricKey,
            preparedLyricKey == pendingLyricKey
      else { return }
      self.pendingLyricKey = nil
      applyPreparedLyric(snapshot, bridge: bridge)
    }

    private func ensurePrepared(_ snapshot: ProjectMLyricsFeed.Snapshot) {
      guard preparedLyricKey != snapshot.key,
            preparingLyricKey != snapshot.key else { return }
      lyricPreparationTask?.cancel()
      destroyPreparedLyric()
      let key = snapshot.key
      let text = snapshot.text
      lyricPreparationGeneration &+= 1
      let generation = lyricPreparationGeneration
      preparingLyricKey = key
      lyricPreparationTask = Task { [weak self] in
        let address = await Task.detached(priority: .userInitiated) {
          text.withCString { pointer in
            resonance_projectm_prepare_lyric(pointer).map { UInt(bitPattern: $0) }
          }
        }.value
        guard !Task.isCancelled else {
          if let address, let pointer = OpaquePointer(bitPattern: address) {
            resonance_projectm_destroy_prepared_lyric(pointer)
          }
          return
        }
        guard let self else {
          if let address, let pointer = OpaquePointer(bitPattern: address) {
            resonance_projectm_destroy_prepared_lyric(pointer)
          }
          return
        }
        guard self.lyricPreparationGeneration == generation,
              self.preparingLyricKey == key else {
          if let address, let pointer = OpaquePointer(bitPattern: address) {
            resonance_projectm_destroy_prepared_lyric(pointer)
          }
          return
        }
        self.preparingLyricKey = nil
        self.preparedLyricKey = key
        self.preparedLyricAddress = address
      }
    }

    private func applyPreparedLyric(
      _ snapshot: ProjectMLyricsFeed.Snapshot,
      bridge: OpaquePointer
    ) {
      guard preparedLyricKey == snapshot.key,
            let preparedLyricAddress,
            let prepared = OpaquePointer(bitPattern: preparedLyricAddress)
      else { return }
      let uploaded = resonance_native_projectm_apply_prepared_lyric(bridge, prepared)
      resonance_projectm_destroy_prepared_lyric(prepared)
      self.preparedLyricAddress = nil
      preparedLyricKey = nil
      preparingLyricKey = nil
      lyricPreparationTask = nil
      guard uploaded else {
        activeLyricKey = nil
        return
      }
      activeLyricKey = snapshot.key
      resonance_native_projectm_set_lyric_progress(bridge, snapshot.progress)
    }

    private func destroyPreparedLyric() {
      if let preparedLyricAddress,
         let prepared = OpaquePointer(bitPattern: preparedLyricAddress) {
        resonance_projectm_destroy_prepared_lyric(prepared)
      }
      preparedLyricAddress = nil
      preparedLyricKey = nil
    }

    private func resetLyricState() {
      lyricPreparationGeneration &+= 1
      lyricPreparationTask?.cancel()
      lyricPreparationTask = nil
      preparingLyricKey = nil
      destroyPreparedLyric()
      activeLyricKey = nil
      pendingLyricKey = nil
    }

    private func recordRenderMetric(_ duration: CFTimeInterval) {
      renderMetricFrames += 1
      renderMetricTotal += duration
      renderMetricMaximum = max(renderMetricMaximum, duration)
      guard renderMetricFrames >= 120 else { return }
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.performance.window",
        details: [
          "frames": String(renderMetricFrames),
          "average_render_ms": String(format: "%.2f", renderMetricTotal * 1000 / Double(renderMetricFrames)),
          "maximum_render_ms": String(format: "%.2f", renderMetricMaximum * 1000),
          "maximum_frame_gap_ms": String(format: "%.2f", frameGapMaximum * 1000),
          "gaps_over_33ms": String(frameGapsOver33ms),
          "gaps_over_50ms": String(frameGapsOver50ms)
        ]
      )
      renderMetricFrames = 0
      renderMetricTotal = 0
      renderMetricMaximum = 0
      frameGapMaximum = 0
      frameGapsOver33ms = 0
      frameGapsOver50ms = 0
    }

    private func resetFPSCounter(notify: Bool) {
      fpsWindowStart = nil
      fpsWindowFrames = 0
      if notify { fpsCallback?(nil) }
    }

    func stop() {
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "projectm.display.stop",
        details: ["reason": "dismantle"]
      )
      // SwiftUI may be destroying the view graph while dismantleUIView runs.
      // Do not call back into @State from this teardown path: the FPS callback
      // is only valid while the representable is actively rendering.
      fpsCallback = nil
      lowFPSCallback = nil
      displayLink?.invalidate()
      displayLink = nil
      if let bridge {
        resonance_native_projectm_destroy(bridge)
      }
      resetLyricState()
      bridge = nil
      loadedPresetWasFocused = false
      lastDrawableSize = .zero
      targetFramebuffer = nil
      view = nil
      resetFPSCounter(notify: false)
    }

  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> GLKView {
    let glContext = EAGLContext(api: .openGLES3)!
    let view = GLKView(frame: .zero, context: glContext)
    view.delegate = context.coordinator
    view.enableSetNeedsDisplay = false
    view.drawableColorFormat = .RGBA8888
    view.drawableDepthFormat = .formatNone
    context.coordinator.makeView(
      view,
      initialPreset: preset,
      isActive: isActive,
      lyricsEnabled: lyricsEnabled,
      lyricsFeed: lyricsFeed,
      onFPSUpdate: onFPSUpdate,
      onSustainedLowFPS: onSustainedLowFPS
    )
    return view
  }

  func updateUIView(_ view: GLKView, context: Context) {
    context.coordinator.setFPSCallback(onFPSUpdate)
    context.coordinator.setLowFPSCallback(onSustainedLowFPS)
    context.coordinator.setLyrics(enabled: lyricsEnabled, feed: lyricsFeed)
    context.coordinator.setActive(isActive, preset: preset)
    context.coordinator.update(preset: preset)
  }

  static func dismantleUIView(_ view: GLKView, coordinator: Coordinator) {
    coordinator.stop()
  }
}
