import Foundation

struct AppReportedError: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let source: String
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), source: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.message = message
    }
}

@MainActor
final class AppErrorLog: ObservableObject {
    @Published private(set) var entries: [AppReportedError]

    private static let persistenceKey = "resonance.reportedErrors"
    private static let maximumEntries = 30

    init() {
        entries = Self.loadEntries()
    }

    var latest: AppReportedError? { entries.first }

    func report(source: String, message: String) {
        let cleanedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedMessage.isEmpty else { return }

        let resolvedSource = cleanedSource.isEmpty ? "Resonance" : cleanedSource
        if let first = entries.first,
           first.source == resolvedSource,
           first.message == cleanedMessage,
           Date().timeIntervalSince(first.timestamp) < 5 {
            return
        }
        let entry = AppReportedError(
            source: resolvedSource,
            message: cleanedMessage
        )
        entries.insert(entry, at: 0)
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
        persist()
    }

    func clear() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        persist()
    }

    func copyText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] \(entry.source): \(entry.message)"
        }.joined(separator: "\n")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    private static func loadEntries() -> [AppReportedError] {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([AppReportedError].self, from: data)
        else {
            return []
        }
        return Array(decoded.prefix(maximumEntries))
    }
}
