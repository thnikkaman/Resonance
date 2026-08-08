import Foundation
import GLKit
import SwiftUI

private struct ResonanceProjectMPreset: Identifiable, Hashable {
  let id: String
  let displayName: String
  let url: URL
}

struct ProjectMFullscreenView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var presets: [ResonanceProjectMPreset] = []
  @State private var selectedID = ""
  @State private var isLoadingPresets = true
  @State private var controlsVisible = false
  @State private var lyricsEnabled = false
  @AppStorage("resonance.projectmd.favoritePresetIDs") private var favoriteIDsRaw = ""
  @AppStorage("resonance.projectmd.banishedPresetIDs") private var banishedIDsRaw = ""

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
        ProjectMFullscreenGLView(preset: selectedPreset)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.easeOut(duration: 0.22)) {
              controlsVisible.toggle()
            }
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
            fullscreenControl(title: lyricsEnabled ? "Lyrics On" : "Lyrics Off", systemImage: "text.quote") {
              lyricsEnabled.toggle()
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
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
    }
    .statusBarHidden(true)
    .interactiveDismissDisabled()
    .task {
      guard presets.isEmpty else { return }
      let presetRoot = Bundle.main.resourceURL?.appendingPathComponent(
        "ProjectMD/CreamOfTheCrop",
        isDirectory: true
      )
      let loaded = await Task.detached(priority: .utility) {
        Self.loadPresets(from: presetRoot)
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
    var updated = favoriteIDs
    if updated.contains(selectedID) {
      updated.remove(selectedID)
    } else {
      updated.insert(selectedID)
    }
    favoriteIDsRaw = updated.sorted().joined(separator: ",")
  }

  private func banishCurrentPreset() {
    guard let selectedPreset, availablePresets.count > 1 else { return }
    let currentIndex = availablePresets.firstIndex(of: selectedPreset) ?? 0
    let next = availablePresets[(currentIndex + 1) % availablePresets.count]
    var updated = banishedIDs
    updated.insert(selectedPreset.id)
    banishedIDsRaw = updated.sorted().joined(separator: ",")
    selectedID = next.id
    controlsVisible = false
  }

  private func movePreset(by offset: Int) {
    guard !availablePresets.isEmpty else { return }
    guard let currentIndex = availablePresets.firstIndex(where: { $0.id == selectedID }) else {
      selectedID = availablePresets.first?.id ?? ""
      return
    }
    let nextIndex = (currentIndex + offset + availablePresets.count) % availablePresets.count
    selectedID = availablePresets[nextIndex].id
  }

  nonisolated private static func loadPresets(from root: URL?) -> [ResonanceProjectMPreset] {
    guard let root, FileManager.default.fileExists(atPath: root.path) else { return [] }
    let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
    let urls = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )?.compactMap { $0 as? URL }.filter { url in
      url.pathExtension.caseInsensitiveCompare("milk") == .orderedSame
    }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } ?? []

    return urls.map { url in
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
  }
}

private struct ProjectMFullscreenGLView: UIViewRepresentable {
  let preset: ResonanceProjectMPreset

  @MainActor
  final class Coordinator: NSObject, @preconcurrency GLKViewDelegate {
    private var bridge: ResonanceProjectMBridge?
    private weak var view: GLKView?
    private var displayLink: CADisplayLink?
    private var loadedPresetID = ""

    func makeView(_ view: GLKView) {
      self.view = view
      bridge = ResonanceProjectMBridge(view: view)
      displayLink = CADisplayLink(target: self, selector: #selector(displayTick))
      displayLink?.preferredFramesPerSecond = 60
      displayLink?.add(to: .main, forMode: .common)
    }

    func update(preset: ResonanceProjectMPreset) {
      guard loadedPresetID != preset.id else { return }
      let smooth = !loadedPresetID.isEmpty
      loadedPresetID = preset.id
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
      bridge?.setTextureSearchPaths([
        preset.url.deletingLastPathComponent().path,
        bundledTextureRoot?.path,
        bundledSpritesRoot?.path,
        textureRoot?.path
      ].compactMap { $0 })
      bridge?.loadPreset(atPath: preset.url.path, smooth: smooth)
    }

    func resize(width: UInt, height: UInt) {
      bridge?.resize(toWidth: width, height: height)
    }

    func glkView(_ view: GLKView, drawIn rect: CGRect) {
      bridge?.drawFrame()
    }

    @objc private func displayTick() {
      guard let view, let window = view.window, !view.isHidden, view.alpha > 0 else { return }
      guard view.convert(view.bounds, to: window).intersects(window.bounds) else { return }
      view.display()
    }

    func stop() {
      displayLink?.invalidate()
      displayLink = nil
      bridge = nil
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
    context.coordinator.makeView(view)
    context.coordinator.update(preset: preset)
    return view
  }

  func updateUIView(_ view: GLKView, context: Context) {
    context.coordinator.update(preset: preset)
    context.coordinator.resize(width: UInt(view.drawableWidth), height: UInt(view.drawableHeight))
  }

  static func dismantleUIView(_ view: GLKView, coordinator: Coordinator) {
    coordinator.stop()
  }
}
