import Foundation

struct SyncedLyricLine: Hashable, Identifiable, Sendable {
  let id: Int
  let startTime: TimeInterval
  let text: String
}

struct LyricsDocument: Sendable, Hashable {
  let syncedLines: [SyncedLyricLine]
  let plainLyrics: String?
  let instrumental: Bool

  var hasSyncedLyrics: Bool { !syncedLines.isEmpty }
}

enum LyricsService {
  private struct Response: Decodable {
    let plainLyrics: String?
    let syncedLyrics: String?
    let instrumental: Bool?
  }

  static func fetch(for track: Track) async -> LyricsDocument? {
    var components = URLComponents(string: "https://lrclib.net/api/get")
    let duration = max(0, Int(track.duration.rounded()))
    components?.queryItems = [
      URLQueryItem(name: "track_name", value: track.title),
      URLQueryItem(name: "artist_name", value: track.artist),
      URLQueryItem(name: "album_name", value: track.album),
      URLQueryItem(name: "duration", value: String(duration))
    ]
    guard let url = components?.url else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 8
    request.setValue("Resonance/2.1 (lyrics lookup)", forHTTPHeaderField: "User-Agent")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      let decoded = try JSONDecoder().decode(Response.self, from: data)
      let syncedLines = parseLRC(decoded.syncedLyrics)
      let plainLyrics = decoded.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !syncedLines.isEmpty || !(plainLyrics?.isEmpty ?? true) || decoded.instrumental == true else {
        return nil
      }
      return LyricsDocument(
        syncedLines: syncedLines,
        plainLyrics: plainLyrics?.isEmpty == true ? nil : plainLyrics,
        instrumental: decoded.instrumental ?? false
      )
    } catch {
      return nil
    }
  }

  private static func parseLRC(_ value: String?) -> [SyncedLyricLine] {
    guard let value else { return [] }
    var parsed: [(TimeInterval, String)] = []
    let pattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }

    for rawLine in value.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
      let matches = expression.matches(in: line, range: fullRange)
      guard !matches.isEmpty else { continue }

      let textStart = matches.reduce(0) { max($0, $1.range.location + $1.range.length) }
      guard textStart <= line.utf16.count else { continue }
      let startIndex = String.Index(utf16Offset: textStart, in: line)
      let lyricText = String(line[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !lyricText.isEmpty else { continue }

      for match in matches {
        guard
          let minutesRange = Range(match.range(at: 1), in: line),
          let secondsRange = Range(match.range(at: 2), in: line),
          let minutes = Double(line[minutesRange]),
          let seconds = Double(line[secondsRange])
        else { continue }

        var fraction = 0.0
        if match.range(at: 3).location != NSNotFound,
           let fractionRange = Range(match.range(at: 3), in: line),
           let rawFraction = Double(line[fractionRange]) {
          fraction = rawFraction / pow(10, Double(line[fractionRange].count))
        }
        parsed.append((minutes * 60 + seconds + fraction, lyricText))
      }
    }

    return parsed
      .sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
      .enumerated()
      .map { SyncedLyricLine(id: $0.offset, startTime: $0.element.0, text: $0.element.1) }
  }
}

@MainActor
final class LyricsStore: ObservableObject {
  @Published private(set) var document: LyricsDocument?
  @Published private(set) var isLoading = false

  private var cache: [String: LyricsDocument?] = [:]
  private var requestTask: Task<Void, Never>?
  private var requestedKey = ""

  func load(for track: Track?) {
    requestTask?.cancel()
    guard let track else {
      requestedKey = ""
      document = nil
      isLoading = false
      return
    }

    let key = Self.key(for: track)
    requestedKey = key
    if let cached = cache[key] {
      document = cached
      isLoading = false
      return
    }

    document = nil
    isLoading = true
    requestTask = Task { [weak self] in
      let result = await LyricsService.fetch(for: track)
      guard !Task.isCancelled else { return }
      guard let self, self.requestedKey == key else { return }
      self.cache[key] = result
      self.document = result
      self.isLoading = false
      ResonanceDiagnostics.shared.recordDeferred(
        "lyrics.lookup.completed",
        details: [
          "found": String(result != nil),
          "synced": String(result?.hasSyncedLyrics == true)
        ]
      )
    }
  }

  private static func key(for track: Track) -> String {
    [track.artist, track.albumArtist, track.album, track.title, String(Int(track.duration.rounded()))]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .joined(separator: "|")
  }
}
