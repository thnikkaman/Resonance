import Foundation

/// Small, privacy-safe diagnostics trail that remains available in the app's
/// Documents directory after an unexpected process termination. It deliberately
/// records lifecycle and playback boundaries, not track names, file paths,
/// server URLs, credentials, or audio data.
final class ResonanceDiagnostics: @unchecked Sendable {
  static let shared = ResonanceDiagnostics()

  private let queue = DispatchQueue(
    label: "com.example.ResonancePrototype.diagnostics",
    qos: .utility
  )
  private let fileURL: URL
  private let maximumBytes = 1_048_576

  private init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    try? FileManager.default.createDirectory(
      at: documents,
      withIntermediateDirectories: true
    )
    fileURL = documents.appendingPathComponent("Resonance-Diagnostics.log")
    record("diagnostics.ready", details: ["location": "Documents/Resonance-Diagnostics.log"])
  }

  func record(_ event: String, details: [String: String] = [:]) {
    let cleanedEvent = sanitize(event)
    let cleanedDetails = details
      .sorted { $0.key < $1.key }
      .map { "\(sanitize($0.key))=\(sanitize($0.value))" }
      .joined(separator: " ")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = cleanedDetails.isEmpty
      ? "\(timestamp) \(cleanedEvent)\n"
      : "\(timestamp) \(cleanedEvent) \(cleanedDetails)\n"

    // Playback-stage records must be on disk before the next framework call;
    // a synchronous serial write makes the last completed boundary useful even
    // when the process terminates immediately afterward.
    queue.sync {
      do {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
          try Data().write(to: fileURL, options: .atomic)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
        trimIfNeeded()
      } catch {
        // Diagnostics must never interfere with playback or app startup.
      }
    }
  }

  private func trimIfNeeded() {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
      let size = attributes[.size] as? Int,
      size > maximumBytes,
      let data = try? Data(contentsOf: fileURL)
    else { return }

    let retained = data.suffix(maximumBytes / 2)
    try? Data(retained).write(to: fileURL, options: .atomic)
  }

  private func sanitize(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
