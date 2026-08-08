import UIKit

@MainActor
final class ResonanceOrientationCoordinator {
  static let shared = ResonanceOrientationCoordinator()

  private(set) var supportedOrientations: UIInterfaceOrientationMask = .portrait

  func setFullscreenEnabled(_ enabled: Bool) {
    supportedOrientations = enabled
      ? [.portrait, .landscapeLeft, .landscapeRight]
      : .portrait

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      windowScene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
  }
}
