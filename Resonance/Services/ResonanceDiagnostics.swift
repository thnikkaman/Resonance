import Foundation

/// Small, privacy-safe diagnostics trail that remains available in the app's
/// Documents directory after an unexpected process termination. It deliberately
/// records lifecycle and playback boundaries, not track names, file paths,
/// server URLs, credentials, or audio data.
final class ResonanceDiagnostics: @unchecked Sendable {
  static let shared = ResonanceDiagnostics()
  private static let debuggingEnabledKey = "resonance.diagnostics.debuggingEnabled"

  private let queue = DispatchQueue(
    label: "com.example.ResonancePrototype.diagnostics",
    qos: .utility
  )
  private let fileURL: URL
  private let maximumBytes = 100 * 1_048_576

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

  var debuggingEnabled: Bool {
    UserDefaults.standard.bool(forKey: Self.debuggingEnabledKey)
  }

  func setDebuggingEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: Self.debuggingEnabledKey)
    record("diagnostics.debuggingMode", details: ["enabled": String(enabled)])
  }

  func fileSizeBytes() -> Int64 {
    queue.sync {
      guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
        let size = attributes[.size] as? NSNumber
      else { return 0 }
      return size.int64Value
    }
  }

  func deleteFile() {
    queue.sync {
      try? FileManager.default.removeItem(at: fileURL)
    }
  }

  func record(_ event: String, details: [String: String] = [:]) {
    let line = makeLine(event, details: details)

    // Playback-stage records must be on disk before the next framework call;
    // a synchronous serial write makes the last completed boundary useful even
    // when the process terminates immediately afterward.
    queue.sync {
      append(line)
    }
  }

  /// Records UI and catalog activity without making the main actor wait for a
  /// filesystem write. These events are useful for performance diagnosis but
  /// are not crash-boundary markers.
  func recordDeferred(_ event: String, details: [String: String] = [:]) {
    guard debuggingEnabled else { return }
    let line = makeLine(event, details: details)
    queue.async { [weak self] in
      self?.append(line)
    }
  }

  private func makeLine(_ event: String, details: [String: String]) -> String {
    let cleanedEvent = sanitize(event)
    let cleanedDetails = details
      .sorted { $0.key < $1.key }
      .map { "\(sanitize($0.key))=\(sanitize($0.value))" }
      .joined(separator: " ")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    return cleanedDetails.isEmpty
      ? "\(timestamp) \(cleanedEvent)\n"
      : "\(timestamp) \(cleanedEvent) \(cleanedDetails)\n"
  }

  private func append(_ line: String) {
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

@_cdecl("resonance_diagnostics_record")
func resonance_diagnostics_record(
  _ event: UnsafePointer<CChar>?,
  _ key: UnsafePointer<CChar>?,
  _ value: UnsafePointer<CChar>?
) {
  guard let event else { return }
  let eventString = String(cString: event)
  var details: [String: String] = [:]
  if let key, let value {
    details[String(cString: key)] = String(cString: value)
  }
  ResonanceDiagnostics.shared.record(eventString, details: details)
}
