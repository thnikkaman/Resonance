import UIKit

@MainActor
final class ResonanceOrientationCoordinator {
  static let shared = ResonanceOrientationCoordinator()

  private(set) var supportedOrientations: UIInterfaceOrientationMask = .portrait

  func setFullscreenEnabled(_ enabled: Bool) {
    supportedOrientations = enabled
      ? [.landscapeLeft, .landscapeRight]
      : .portrait

    ResonanceDiagnostics.shared.recordDeferredAlways(
      "projectm.orientation.request",
      details: ["fullscreen": String(enabled), "mask": enabled ? "landscape" : "portrait"]
    )

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      windowScene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      if #available(iOS 16.0, *) {
        let preferences: UIWindowScene.GeometryPreferences = enabled
          ? .iOS(interfaceOrientations: .landscape)
          : .iOS(interfaceOrientations: .portrait)
        windowScene.requestGeometryUpdate(preferences)
      }
    }
  }
}
