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

private struct ResonanceProjectMPreset: Identifiable, Hashable {
  let id: String
  let displayName: String
  let url: URL
}

struct ProjectMFullscreenView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var presets: [ResonanceProjectMPreset] = []
  @State private var selectedID = ""
  @State private var isLoadingPresets = true
  @State private var controlsVisible = false
  @State private var lyricsEnabled = false
  @State private var rendererActive = false
  @State private var rendererGeneration = 0
  @State private var lowFPSBanishing = false
  @StateObject private var lyricsFeed = ProjectMLyricsFeed()
  @AppStorage("resonance.projectmd.favoritePresetIDs") private var favoriteIDsRaw = ""
  @AppStorage("resonance.projectmd.banishedPresetIDs") private var banishedIDsRaw = ""
  @AppStorage("resonance.projectmd.shufflePresets") private var shufflePresets = true
  @AppStorage("resonance.projectmd.autoCyclePresets") private var autoCyclePresets = true
  @AppStorage("resonance.projectmd.fullscreenDefaultsConfigured") private var fullscreenDefaultsConfigured = false
  private let presetCycleTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  private var favoriteIDs: Set<String> {
    Set(favoriteIDsRaw.split(separator: ",").map(String.init))
  }

  private var banishedIDs: Set<String> {
    Set(banishedIDsRaw.split(separator: ",").map(String.init))
  }

  private var availablePresets: [ResonanceProjectMPreset] {
    presets.filter { !banishedIDs.contains($0.id) }
  }

  private var selectedPreset: ResonanceProjectMPreset? {
    availablePresets.first(where: { $0.id == selectedID }) ?? availablePresets.first
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let selectedPreset {
        ProjectMFullscreenGLView(
          preset: selectedPreset,
          isActive: rendererActive,
          lyricsEnabled: lyricsEnabled,
          lyricsFeed: lyricsFeed,
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
            ResonanceDiagnostics.shared.recordDeferred(
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
                movePreset(by: horizontal < 0 ? 1 : -1)
              }
          )
      } else if isLoadingPresets {
        ProgressView("Loading visualizations…")
          .tint(.white)
          .foregroundStyle(.white)
      } else {
        Text("No visualizations found in ProjectMD")
          .foregroundStyle(.white)
      }

      if controlsVisible {
        VStack {
          HStack {
            ProjectMPlaybackControl()
              .transition(.move(edge: .leading).combined(with: .opacity))
            Spacer()
            fullscreenControl(title: lyricsEnabled ? "Lyrics On" : "Lyrics Off", systemImage: "text.quote") {
              lyricsEnabled.toggle()
              ResonanceDiagnostics.shared.recordDeferred(
                "projectm.lyrics.toggle",
                details: ["enabled": String(lyricsEnabled)]
              )
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
            Spacer()
            fullscreenControl(
              title: shufflePresets ? "Shuffle On" : "Shuffle Off",
              systemImage: "shuffle"
            ) {
              shufflePresets.toggle()
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
          HStack {
            Spacer()
            fullscreenControl(title: "Banish", systemImage: "nosign") {
              banishCurrentPreset()
            }
            .disabled(availablePresets.count <= 1)
            .opacity(availablePresets.count > 1 ? 1 : 0.5)
            .transition(.move(edge: .trailing).combined(with: .opacity))
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 30)
        .animation(.easeOut(duration: 0.22), value: controlsVisible)
      }

      ProjectMLyricsFeedHost(feed: lyricsFeed, enabled: lyricsEnabled)

      ProjectMDownloadFlushOnDisappear()
    }
    .statusBarHidden(true)
    .interactiveDismissDisabled()
    .onAppear {
      ResonanceOrientationCoordinator.shared.setFullscreenEnabled(true)
      ProjectMActivityCoordinator.shared.setActive(true)
      rendererActive = scenePhase == .active
    }
    .onDisappear {
      ResonanceOrientationCoordinator.shared.setFullscreenEnabled(false)
      ProjectMActivityCoordinator.shared.setActive(false)
    }
    .onChange(of: scenePhase) { _, phase in
      // A CADisplayLink can remain retained while a full-screen cover is
      // inactive (phone lock, app switcher, or a scene transition). Tear down
      // the native renderer so it cannot keep consuming GPU/CPU and audio
      // staging work while no frame can be presented.
      rendererActive = phase == .active
      ResonanceDiagnostics.shared.recordDeferred(
        "projectm.scene.renderer",
        details: ["phase": String(describing: phase), "active": String(phase == .active)]
      )
    }
    .onReceive(presetCycleTimer) { _ in
      guard scenePhase == .active, autoCyclePresets, !isLoadingPresets, !availablePresets.isEmpty else { return }
      movePreset(by: 1)
    }
    .task {
      if !fullscreenDefaultsConfigured {
        // Resonance did not previously expose these fullscreen options. Make
        // the first integrated experience match ProjectMD's default behavior,
        // while preserving any later user choice.
        shufflePresets = true
        autoCyclePresets = true
        fullscreenDefaultsConfigured = true
      }
      guard presets.isEmpty else { return }
      let projectMRoot = Bundle.main.resourceURL?.appendingPathComponent(
        "ProjectMD",
        isDirectory: true
      )
      let loaded = await Task.detached(priority: .utility) {
        Self.loadPresets(from: projectMRoot)
      }.value
      presets = loaded.filter { !banishedIDs.contains($0.id) }
      selectedID = presets.first?.id ?? ""
      isLoadingPresets = false
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
    ResonanceDiagnostics.shared.recordDeferred(
      "projectm.preset.favorite",
      details: ["preset": selectedPreset.id, "enabled": String(updated.contains(selectedPreset.id))]
    )
  }

  private func banishCurrentPreset() {
    guard let selectedPreset, availablePresets.count > 1 else { return }
    let remaining = availablePresets.filter { $0.id != selectedPreset.id }
    guard let next = nextPreset(from: remaining) else { return }
    let oldID = selectedPreset.id
    rendererActive = false
    var updated = banishedIDs
    updated.insert(oldID)
    banishedIDsRaw = updated.sorted().joined(separator: ",")
    selectedID = next.id
    controlsVisible = false
    rendererGeneration += 1
    ResonanceDiagnostics.shared.recordDeferred(
      "projectm.preset.banished",
      details: ["preset": oldID, "next": next.id]
    )
    DispatchQueue.main.async {
      rendererActive = true
    }
  }

  private func nextPreset(from choices: [ResonanceProjectMPreset]) -> ResonanceProjectMPreset? {
    guard !choices.isEmpty else { return nil }
    if shufflePresets {
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
    ResonanceDiagnostics.shared.recordDeferred(
      "projectm.preset.auto_banished",
      details: [
        "preset": selectedPreset.id,
        "fps": String(format: "%.1f", fps),
        "duration_seconds": String(format: "%.1f", duration)
      ]
    )
    banishCurrentPreset()
    lowFPSBanishing = false
  }

  private func movePreset(by offset: Int) {
    guard !availablePresets.isEmpty else { return }
    guard let currentIndex = availablePresets.firstIndex(where: { $0.id == selectedID }) else {
      selectedID = availablePresets.first?.id ?? ""
      return
    }
    if shufflePresets, offset > 0 {
      let candidates = availablePresets.filter { $0.id != selectedID }
      var weighted: [ResonanceProjectMPreset] = []
      weighted.reserveCapacity(candidates.count)
      for candidate in candidates {
        weighted.append(contentsOf: Array(
          repeating: candidate,
          count: favoriteIDs.contains(candidate.id) ? 10 : 1
        ))
      }
      selectedID = weighted.randomElement()?.id ?? selectedID
      return
    }
    let nextIndex = (currentIndex + offset + availablePresets.count) % availablePresets.count
    selectedID = availablePresets[nextIndex].id
  }

  nonisolated private static func loadPresets(from projectMRoot: URL?) -> [ResonanceProjectMPreset] {
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
        url: url
      )
    }

    let root = projectMRoot.appendingPathComponent("CreamOfTheCrop", isDirectory: true)
    guard FileManager.default.fileExists(atPath: root.path) else { return focusedPresets }
    let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
    let urls = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )?.compactMap { $0 as? URL }.filter { url in
      url.pathExtension.caseInsensitiveCompare("milk") == .orderedSame
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } ?? []

    let catalogPresets = urls.map { url in
      let relativePath = String(url.path.dropFirst(rootPath.count))
      let components = relativePath.split(separator: "/").map(String.init)
      let filename = url.deletingPathExtension().lastPathComponent
      let category = components.dropLast().joined(separator: " / ")
      return ResonanceProjectMPreset(
        id: "resonance.projectmd.\(relativePath)",
        displayName: category.isEmpty ? filename : "\(category) · \(filename)",
        url: url
      )
    }
    return focusedPresets + catalogPresets
  }
}

private struct ProjectMPlaybackControl: View {
  @EnvironmentObject private var player: PlayerController

  var body: some View {
    Button {
      let willPlay = !player.isPlaying
      player.toggle()
      ResonanceDiagnostics.shared.recordDeferred(
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

@MainActor
private final class ProjectMLyricsFeed: ObservableObject {
  struct Snapshot {
    let key: String
    let text: String
    let progress: Float
  }

  private var trackKey = ""
  private var trackDuration: TimeInterval = 0
  private var document: LyricsDocument?
  private var elapsed: TimeInterval = 0
  private var enabled = false

  func updateTrack(_ track: Track?) {
    let nextKey = track?.id.uuidString ?? ""
    guard nextKey != trackKey else {
      trackDuration = track?.duration ?? 0
      return
    }
    trackKey = nextKey
    trackDuration = track?.duration ?? 0
    document = nil
    elapsed = 0
  }

  func update(document: LyricsDocument?) {
    self.document = document
  }

  func update(elapsed: TimeInterval) {
    self.elapsed = elapsed
  }

  func update(enabled: Bool) {
    self.enabled = enabled
  }

  func snapshot() -> Snapshot? {
    guard enabled,
          !trackKey.isEmpty,
          let lines = document?.syncedLines,
          !lines.isEmpty,
          elapsed >= lines[0].startTime
    else { return nil }

    var low = 0
    var high = lines.count
    while low < high {
      let middle = (low + high) / 2
      if lines[middle].startTime <= elapsed {
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
    guard elapsed < endTime else { return nil }
    let duration = max(0.8, endTime - line.startTime)
    let progress = Float(min(1, max(0, (elapsed - line.startTime) / duration)))
    return Snapshot(
      key: "\(trackKey):\(line.id)",
      text: line.text,
      progress: progress
    )
  }
}

private struct ProjectMLyricsFeedHost: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var playbackProgress: PlaybackProgress
  @StateObject private var lyricsStore = LyricsStore()
  let feed: ProjectMLyricsFeed
  let enabled: Bool

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .onAppear {
        feed.updateTrack(player.currentTrack)
        feed.update(document: lyricsStore.document)
        feed.update(elapsed: playbackProgress.elapsed)
        feed.update(enabled: enabled)
      }
      .onChange(of: enabled) { _, value in
        feed.update(enabled: value)
        lyricsStore.load(for: value ? player.currentTrack : nil)
      }
      .onChange(of: player.currentTrack?.id) { _, _ in
        feed.updateTrack(player.currentTrack)
      }
      .onReceive(playbackProgress.$elapsed) { elapsed in
        feed.update(elapsed: elapsed)
      }
      .onReceive(lyricsStore.$document) { document in
        feed.update(document: document)
      }
      .task(id: "\(player.currentTrack?.id.uuidString ?? "none"):\(enabled)") {
        lyricsStore.load(for: enabled ? player.currentTrack : nil)
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
  let onSustainedLowFPS: @MainActor (Double, TimeInterval) -> Void

  nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.preset.id == rhs.preset.id &&
      lhs.isActive == rhs.isActive &&
      lhs.lyricsEnabled == rhs.lyricsEnabled
  }

  @MainActor
  final class Coordinator: NSObject, @preconcurrency GLKViewDelegate {
    private let maximumDrawableScale: CGFloat = 0.75
    private var bridge: OpaquePointer?
    private weak var view: GLKView?
    private var displayLink: CADisplayLink?
    private var loadedPresetID = ""
    private var lastDrawableSize = CGSize.zero
    private var targetFramebuffer: UInt32?
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
      onSustainedLowFPS: @escaping @MainActor (Double, TimeInterval) -> Void
    ) {
      self.view = view
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
        ResonanceDiagnostics.shared.recordDeferred(
          "projectm.display.start",
          details: ["reason": "active"]
        )
        EAGLContext.setCurrent(view.context)
        bridge = resonance_native_projectm_create()
        loadedPresetID = ""
        update(preset: preset)
        let link = CADisplayLink(target: self, selector: #selector(displayTick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
      } else {
        guard bridge != nil || displayLink != nil else { return }
        ResonanceDiagnostics.shared.recordDeferred(
          "projectm.display.stop",
          details: ["reason": "inactive"]
        )
        displayLink?.invalidate()
        displayLink = nil
        if let bridge {
          resonance_native_projectm_destroy(bridge)
        }
        bridge = nil
        lastDrawableSize = .zero
        targetFramebuffer = nil
        lastFrameStart = 0
        timingIntervals = 0
        timingElapsed = 0
        measuredFPS = nil
        lowPerformanceSince = nil
        lowPerformanceTriggered = false
        lowPerformanceEligibleAt = 0
        resetLyricState()
      }
    }

    func setLowFPSCallback(_ callback: @escaping @MainActor (Double, TimeInterval) -> Void) {
      lowFPSCallback = callback
    }

    func setLyrics(enabled: Bool, feed: ProjectMLyricsFeed) {
      guard lyricsEnabled != enabled || lyricsFeed !== feed else { return }
      lyricsEnabled = enabled
      lyricsFeed = feed
      feed.update(enabled: enabled)
    }

    func update(preset: ResonanceProjectMPreset) {
      guard loadedPresetID != preset.id else { return }
      let smooth = !loadedPresetID.isEmpty
      loadedPresetID = preset.id
      lowPerformanceSince = nil
      lowPerformanceTriggered = false
      // Do not classify the intentional preset transition as a failed preset.
      lowPerformanceEligibleAt = CACurrentMediaTime() + 1.5
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
      ResonanceDiagnostics.shared.record(
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
      if lastFrameStart > 0 {
        let interval = frameStart - lastFrameStart
        if interval > 0, interval < 0.5 {
          frameGapMaximum = max(frameGapMaximum, interval)
          if interval >= (1.0 / 30.0) { frameGapsOver33ms += 1 }
          if interval >= 0.05 { frameGapsOver50ms += 1 }
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
      // GLKView binds the same drawable framebuffer for each frame. Query it
      // only on first use or after a drawable resize; glGetIntegerv is a
      // synchronous driver round trip and doing it at 60 Hz makes button
      // animations and transitions compete with the renderer.
      if targetFramebuffer == nil || drawableResized {
        var framebuffer: GLint = 0
        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &framebuffer)
        let resolved = UInt32(max(framebuffer, 0))
        targetFramebuffer = resolved
        resonance_native_projectm_set_target_framebuffer(bridge, resolved)
      }
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
      ResonanceDiagnostics.shared.recordDeferred(
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

    func stop() {
      ResonanceDiagnostics.shared.recordDeferred(
        "projectm.display.stop",
        details: ["reason": "dismantle"]
      )
      displayLink?.invalidate()
      displayLink = nil
      if let bridge {
        resonance_native_projectm_destroy(bridge)
      }
      resetLyricState()
      bridge = nil
      lastDrawableSize = .zero
      targetFramebuffer = nil
      view = nil
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
      onSustainedLowFPS: onSustainedLowFPS
    )
    return view
  }

  func updateUIView(_ view: GLKView, context: Context) {
    context.coordinator.setLowFPSCallback(onSustainedLowFPS)
    context.coordinator.setLyrics(enabled: lyricsEnabled, feed: lyricsFeed)
    context.coordinator.setActive(isActive, preset: preset)
    context.coordinator.update(preset: preset)
  }

  static func dismantleUIView(_ view: GLKView, coordinator: Coordinator) {
    coordinator.stop()
  }
}
