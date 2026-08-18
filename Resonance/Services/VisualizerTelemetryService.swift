import Foundation

enum VisualizerTelemetryConfiguration {
  static let enabledKey = "resonance.visualizer.telemetryEnabled"
  static let endpointString = "https://music.koolkidz.us/resonance/telemetry/events"
  static let bearerTokenInfoKey = "ResonanceVisualizerTelemetryBearerToken"
  static let maximumPendingEvents = 32

#if RESONANCE_TELEMETRY
  static let isCompiledIn = true
#else
  static let isCompiledIn = false
#endif

  static var endpoint: URL {
    URL(string: endpointString)!
  }

  static var bearerToken: String? {
    guard isCompiledIn else { return nil }
    guard let raw = Bundle.main.object(forInfoDictionaryKey: bearerTokenInfoKey) as? String else {
      return nil
    }
    let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty, !token.hasPrefix("$(") else { return nil }
    return token
  }
}

struct VisualizerTelemetryEvent: Codable, Equatable, Sendable {
  let eventId: String
  let presetId: String
  let visualization: String
  let banishmentReason: String
  let fps: Double
  let frameGapMilliseconds: Double
  let appBuild: String
  let osMajor: String
  let occurredAt: String
}

/// Sends only opt-in, low-volume visualizer banishment measurements. The actor
/// owns a bounded in-memory queue so neither the display callback nor the main
/// actor performs network or file I/O.
actor VisualizerTelemetryService {
  static let shared = VisualizerTelemetryService()

  private var pendingEvents: [VisualizerTelemetryEvent] = []
  private var flushTask: Task<Void, Never>?
  private var requestInFlight = false

  func enqueueLowFramerateBanish(
    visualizationID: String,
    measuredFPS: Double
  ) {
    guard VisualizerTelemetryConfiguration.isCompiledIn,
          UserDefaults.standard.bool(forKey: VisualizerTelemetryConfiguration.enabledKey),
          VisualizerTelemetryConfiguration.bearerToken != nil
    else {
      pendingEvents.removeAll(keepingCapacity: true)
      return
    }
    guard measuredFPS.isFinite,
          measuredFPS > 0,
          !visualizationID.isEmpty
    else { return }

    let event = VisualizerTelemetryEvent(
      eventId: UUID().uuidString,
      presetId: clean(visualizationID, maximumLength: 512),
      visualization: "ProjectM",
      banishmentReason: "low_fps",
      fps: (measuredFPS * 10).rounded() / 10,
      frameGapMilliseconds: ((1000 / measuredFPS) * 10).rounded() / 10,
      appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
      osMajor: String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion),
      occurredAt: Self.timestamp()
    )
    pendingEvents.append(event)
    if pendingEvents.count > VisualizerTelemetryConfiguration.maximumPendingEvents {
      pendingEvents.removeFirst(pendingEvents.count - VisualizerTelemetryConfiguration.maximumPendingEvents)
    }

    scheduleFlush(afterNanoseconds: pendingEvents.count == 1 ? 2_000_000_000 : 500_000_000)
  }

  private func scheduleFlush(afterNanoseconds delay: UInt64) {
    flushTask?.cancel()
    flushTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      await self?.flush()
    }
  }

  private func flush() async {
    flushTask = nil
    guard VisualizerTelemetryConfiguration.isCompiledIn,
          UserDefaults.standard.bool(forKey: VisualizerTelemetryConfiguration.enabledKey),
          VisualizerTelemetryConfiguration.bearerToken != nil
    else {
      pendingEvents.removeAll(keepingCapacity: true)
      return
    }
    guard !requestInFlight, let event = pendingEvents.first else { return }

    requestInFlight = true
    var nextDelay: UInt64 = 500_000_000
    defer {
      requestInFlight = false
      if !pendingEvents.isEmpty {
        scheduleFlush(afterNanoseconds: nextDelay)
      }
    }

    do {
      var request = URLRequest(url: VisualizerTelemetryConfiguration.endpoint)
      request.httpMethod = "POST"
      request.timeoutInterval = 10
      request.cachePolicy = .reloadIgnoringLocalCacheData
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(VisualizerTelemetryConfiguration.bearerToken!)", forHTTPHeaderField: "Authorization")
      request.httpBody = try JSONEncoder().encode(event)

      let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
      else {
        throw URLError(.badServerResponse)
      }
      pendingEvents.removeFirst()
    } catch {
      // Preserve the event for a later retry. Its UUID remains stable so the
      // server's INSERT OR IGNORE behavior makes retries idempotent.
      nextDelay = 30_000_000_000
    }
  }

  private static func timestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }

  private func clean(_ value: String, maximumLength: Int) -> String {
    String(
      value
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .prefix(maximumLength)
    )
  }
}
