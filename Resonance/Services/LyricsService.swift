import Foundation
import CryptoKit

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

  var hasReadableLyrics: Bool {
    hasSyncedLyrics || !(plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
  }

  var displayText: String {
    if let plainLyrics, !plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return plainLyrics
    }
    return syncedLines.map(\.text).joined(separator: "\n")
  }
}

enum LyricsRequestMethod: String, CaseIterable, Identifiable, Sendable {
  case get
  case postJSON

  var id: String { rawValue }

  var title: String {
    switch self {
    case .get: "GET"
    case .postJSON: "POST JSON"
    }
  }
}

enum LyricsResponseFormat: String, CaseIterable, Identifiable, Sendable {
  case json
  case lrc

  var id: String { rawValue }

  var title: String {
    switch self {
    case .json: "JSON response"
    case .lrc: "Plain LRC/text response"
    }
  }
}

enum LyricsAuthorizationMode: String, CaseIterable, Identifiable, Sendable {
  case none
  case bearerHeader
  case customHeader
  case queryParameter

  var id: String { rawValue }

  var title: String {
    switch self {
    case .none: "No token"
    case .bearerHeader: "Bearer token header"
    case .customHeader: "Custom header token"
    case .queryParameter: "Query-parameter token"
    }
  }
}

struct LyricsProviderConfiguration: Hashable, Sendable {
  let name: String
  let endpoint: String
  let requestMethod: LyricsRequestMethod
  let responseFormat: LyricsResponseFormat
  let titleParameter: String
  let artistParameter: String
  let albumParameter: String
  let durationParameter: String
  let plainResponsePath: String
  let syncedResponsePath: String
  let authorizationMode: LyricsAuthorizationMode
  let authorizationName: String
  let authorizationToken: String
  let userAgent: String

  var cacheKey: String {
    [
      name, endpoint, requestMethod.rawValue, responseFormat.rawValue,
      titleParameter, artistParameter, albumParameter, durationParameter,
      plainResponsePath, syncedResponsePath, authorizationMode.rawValue,
      authorizationName, authorizationToken, userAgent
    ].joined(separator: "\u{001F}")
  }

  var isUsable: Bool {
    guard !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let url = URL(string: endpoint),
          url.scheme?.lowercased() == "https",
          url.host != nil else { return false }

    if authorizationMode != .none {
      guard !authorizationToken.isEmpty else { return false }
      if authorizationMode == .customHeader || authorizationMode == .queryParameter {
        guard !authorizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
      }
    }
    if responseFormat == .json {
      guard !plainResponsePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          || !syncedResponsePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    }
    return true
  }
}

enum LyricsService {
  private static let durationToleranceSeconds = 5

  private static let localOverrideDirectoryURL: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let directory = base.appendingPathComponent("LyricsOverrides", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }()

  static func document(fromLRCData data: Data) -> LyricsDocument? {
    guard let text = lrcText(from: data)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty else { return nil }

    let document = makeDocument(
      plainLyrics: text.contains("[") ? nil : text,
      syncedLyrics: text,
      instrumental: false
    )
    return document.hasReadableLyrics ? document : nil
  }

  static func localDocument(
    for track: Track,
    searchSiblingFile: Bool
  ) async -> LyricsDocument? {
    return await Task.detached(priority: .utility) {
      let selectedRoot = resolvedSelectedFolderURL()
      let selectedRootAccessed = selectedRoot?.startAccessingSecurityScopedResource() ?? false
      defer {
        if selectedRootAccessed { selectedRoot?.stopAccessingSecurityScopedResource() }
      }

      var foundSiblingData = false
      let candidates: [(kind: String, load: () -> Data?)] = [
        ("override", { coordinatedData(at: localOverrideURL(for: track)) }),
        ("scannedCompanion", { scannedCompanionData(for: track) }),
        ("selectedFolderRelative", { selectedFolderRelativeLRCData(for: track, selectedRoot: selectedRoot) }),
        ("directSibling", { track.fileURL.flatMap { coordinatedSiblingLRCData(for: track, beside: $0) } }),
        ("selectedRelative", { selectedFolderSiblingLRCData(for: track, selectedRoot: selectedRoot) }),
        ("selectedSearch", { selectedFolderMatchLRCData(for: track, selectedRoot: selectedRoot) })
      ]

      for candidate in candidates {
        let data = candidate.load()
        if candidate.kind != "override", data != nil {
          foundSiblingData = true
        }
        guard let data,
              let document = document(fromLRCData: data) else { continue }
        ResonanceDiagnostics.shared.recordDeferredAlways(
          "lyrics.local.lookup",
          details: [
            "audioURL": String(track.fileURL?.isFileURL == true),
            "audioExists": String(track.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false),
            "siblingCandidate": String(foundSiblingData),
            "siblingExists": String(foundSiblingData),
            "selectedFolderBookmark": String(selectedRoot != nil),
            "requestedSiblingSearch": String(searchSiblingFile),
            "overrideCandidate": "true"
          ]
        )
        ResonanceDiagnostics.shared.recordDeferredAlways(
          "lyrics.local.lookup.result",
          details: [
            "candidate": candidate.kind,
            "parsed": "true",
            "synced": String(document.hasSyncedLyrics)
          ]
        )
        return document
      }
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "lyrics.local.lookup",
        details: [
          "audioURL": String(track.fileURL?.isFileURL == true),
          "audioExists": String(track.fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false),
          "siblingCandidate": String(foundSiblingData),
          "siblingExists": String(foundSiblingData),
          "selectedFolderBookmark": String(selectedRoot != nil),
          "requestedSiblingSearch": String(searchSiblingFile),
          "overrideCandidate": "true"
        ]
      )
      ResonanceDiagnostics.shared.recordDeferredAlways(
        "lyrics.local.lookup.result",
        details: ["candidate": "none", "parsed": "false"]
      )
      return nil
    }.value
  }

  private static func lrcText(from data: Data) -> String? {
    // UTF-8 is common, but audiobook companion files are frequently exported
    // by Windows tools as UTF-16 (with or without a BOM). Latin-1 is a safe
    // final fallback for older tagger/exporter output.
    String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .utf16)
      ?? String(data: data, encoding: .utf16LittleEndian)
      ?? String(data: data, encoding: .utf16BigEndian)
      ?? String(data: data, encoding: .utf32)
      ?? String(data: data, encoding: .isoLatin1)
  }

  static func saveLocalOverride(_ data: Data, for track: Track) throws {
    try FileManager.default.createDirectory(
      at: localOverrideDirectoryURL,
      withIntermediateDirectories: true
    )
    try data.write(to: localOverrideURL(for: track), options: .atomic)
  }

  private static func localTrackKey(for track: Track) -> String {
    if let fileURL = track.fileURL, fileURL.isFileURL {
      return "file:\(fileURL.standardizedFileURL.path)"
    }
    return "id:\(track.id.uuidString)"
  }

  private static func localOverrideURL(for track: Track) -> URL {
    let digest = SHA256.hash(data: Data(localTrackKey(for: track).utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    return localOverrideDirectoryURL.appendingPathComponent(digest).appendingPathExtension("lrc")
  }

  private static func coordinatedData(at url: URL) -> Data? {
    (try? ExternalFileCoordinator.read(at: url) { coordinatedURL in
      try Data(contentsOf: coordinatedURL)
    }) ?? (try? Data(contentsOf: url))
  }

  private static func scannedCompanionData(for track: Track) -> Data? {
    guard let fileURL = track.fileURL, fileURL.isFileURL else { return nil }
    let key = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    return PersistentLyricsCompanionDataStore.load()[key]
  }

  private static func coordinatedSiblingLRCData(for track: Track, beside audioURL: URL) -> Data? {
    guard audioURL.isFileURL else { return nil }
    let exact = audioURL.deletingPathExtension().appendingPathExtension("lrc")
    let audioAccessed = audioURL.startAccessingSecurityScopedResource()
    defer {
      if audioAccessed { audioURL.stopAccessingSecurityScopedResource() }
    }

    // The user-selected folder grants access to its children. For an exact
    // same-basename companion, read that URL directly first so File Provider
    // can materialize the sidecar without requiring directory enumeration.
    if let data = try? Data(contentsOf: exact) {
      return data
    }

    // File Provider URLs can expose the audio item while returning an empty
    // or incomplete directory view when the parent directory itself is the
    // coordination anchor. Coordinate the known audio item first, then use
    // the provider's coordinated URL to inspect its sibling directory while
    // that item access is still active.
    return try? ExternalFileCoordinator.read(at: audioURL) { coordinatedAudio in
      let coordinatedParent = coordinatedAudio.deletingLastPathComponent()
      let baseName = coordinatedAudio.deletingPathExtension().lastPathComponent
      let audioMatchKey = LyricsCompanionMatcher.matchKey(
        parentPath: coordinatedParent.path,
        stem: baseName
      )
      let coordinatedExact = coordinatedAudio.deletingPathExtension().appendingPathExtension("lrc")
      if let data = try? Data(contentsOf: coordinatedExact) {
        return data
      }

      let contents = try FileManager.default.contentsOfDirectory(
        at: coordinatedParent,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
      guard let match = contents.first(where: { candidate in
        candidate.pathExtension.caseInsensitiveCompare("lrc") == .orderedSame
          && (LyricsCompanionMatcher.matchKey(
            parentPath: coordinatedParent.path,
            stem: candidate.deletingPathExtension().lastPathComponent
          ) == audioMatchKey
            || ((try? Data(contentsOf: candidate)).flatMap(LyricsCompanionMatcher.metadata).map {
              LyricsCompanionMatcher.metadataMatches(
                $0,
                title: track.title,
                album: track.album,
                artist: track.artist,
                trackNumber: track.trackNumber,
                discNumber: track.discNumber
              )
            } ?? false))
      }) else { return nil }
      return try Data(contentsOf: match)
    }
  }

  /// Read the companion by deriving its path from the security-scoped library
  /// folder. File Provider may expose the audio URL but refuse a sibling URL
  /// derived from that item; the selected folder bookmark is the authority for
  /// both files.
  private static func selectedFolderRelativeLRCData(for track: Track, selectedRoot: URL?) -> Data? {
    guard let fileURL = track.fileURL, fileURL.isFileURL, let selectedRoot else { return nil }
    let root = selectedRoot.standardizedFileURL
    let audioPath = fileURL.standardizedFileURL.path
    let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
    guard audioPath.hasPrefix(rootPath) else { return nil }

    let relativePath = String(audioPath.dropFirst(rootPath.count))
    guard !relativePath.isEmpty else { return nil }
    let selectedAudioURL = root.appendingPathComponent(relativePath)
    let selectedLRCURL = selectedAudioURL.deletingPathExtension().appendingPathExtension("lrc")
    return try? ExternalFileCoordinator.read(at: selectedLRCURL) { coordinatedURL in
      try Data(contentsOf: coordinatedURL)
    }
  }

  private static func resolvedSelectedFolderURL() -> URL? {
    guard let bookmark = PersistentMusicFolderBookmarkStore.load() else { return nil }
    var isStale = false
    return try? URL(
      resolvingBookmarkData: bookmark,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  /// Cached tracks from before a persistent Files folder was selected can
  /// still point into the app's legacy managed folder. Resolve the same
  /// relative audio path against the persisted selected folder so lyric
  /// lookup remains correct even before LibraryStore finishes rehydrating.
  private static func selectedFolderSiblingLRCData(for track: Track, selectedRoot: URL?) -> Data? {
    guard let fileURL = track.fileURL, fileURL.isFileURL else { return nil }
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let legacyRoot = documentsURL.appendingPathComponent(
      "Resonance Music",
      isDirectory: true
    ).standardizedFileURL
    let path = fileURL.standardizedFileURL.path
    let prefix = legacyRoot.path.hasSuffix("/") ? legacyRoot.path : legacyRoot.path + "/"
    guard path.hasPrefix(prefix) else { return nil }

    guard let selectedRoot else { return nil }

    let relativeAudioPath = String(path.dropFirst(prefix.count))
    guard !relativeAudioPath.isEmpty else { return nil }
    let selectedAudioURL = selectedRoot.appendingPathComponent(relativeAudioPath)
    return coordinatedSiblingLRCData(for: track, beside: selectedAudioURL)
  }

  /// Last-resort lookup for a stale cached audio URL. Resolve the audio's
  /// parent against the selected library root, then inspect only that folder.
  /// An audiobook sidecar must never be matched from another album folder.
  private static func selectedFolderMatchLRCData(for track: Track, selectedRoot: URL?) -> Data? {
    guard let fileURL = track.fileURL, fileURL.isFileURL,
          let selectedRoot else { return nil }
    let baseName = fileURL.deletingPathExtension().lastPathComponent
    let selectedRootPath = selectedRoot.standardizedFileURL.path
    let audioPath = fileURL.standardizedFileURL.path
    let legacyRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Resonance Music", isDirectory: true)
      .standardizedFileURL.path
    let folderURL: URL
    if audioPath == selectedRootPath || audioPath.hasPrefix(selectedRootPath + "/") {
      folderURL = fileURL.deletingLastPathComponent()
    } else if audioPath.hasPrefix(legacyRoot + "/") {
      let relative = String(audioPath.dropFirst(legacyRoot.count + 1))
      folderURL = selectedRoot
        .appendingPathComponent(relative)
        .deletingLastPathComponent()
    } else {
      return nil
    }

    // File Provider-backed folders can return an incomplete enumerator snapshot
    // after new files are added. Walk this one coordinated MP3 directory
    // explicitly; a newly copied LRC is eligible immediately without scanning
    // the rest of the library.
    var directories = [folderURL]
    var exactNameCandidate: Data?
    while let directory = directories.popLast() {
      guard let children = try? ExternalFileCoordinator.read(at: directory, { coordinatedDirectory in
        try FileManager.default.contentsOfDirectory(
          at: coordinatedDirectory,
          includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
          options: [.skipsHiddenFiles]
        )
      }) else { continue }

      for child in children {
        if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
          directories.append(child)
          continue
        }
        guard child.pathExtension.caseInsensitiveCompare("lrc") == .orderedSame,
              (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              let data = try? ExternalFileCoordinator.read(at: child, { coordinatedURL in
                try Data(contentsOf: coordinatedURL)
              })
        else { continue }

        if child.deletingPathExtension().lastPathComponent
          .localizedCaseInsensitiveCompare(baseName) == .orderedSame {
          exactNameCandidate = data
        }
        if let metadata = LyricsCompanionMatcher.metadata(from: data),
           LyricsCompanionMatcher.metadataMatches(
             metadata,
             title: track.title,
             album: track.album,
             artist: track.artist,
             trackNumber: track.trackNumber,
             discNumber: track.discNumber
           ) {
          return data
        }
      }
    }
    return exactNameCandidate
  }

  static func fetch(
    for track: Track,
    configuration: LyricsProviderConfiguration
  ) async -> LyricsDocument? {
    guard configuration.isUsable,
          let endpoint = URL(string: configuration.endpoint) else { return nil }

    let baseParameters: [(String, String)] = [
      (configuration.titleParameter, track.title),
      (configuration.artistParameter, track.artist),
      (configuration.albumParameter, track.album)
    ].filter { !$0.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // LRCLIB's /api/get endpoint requires an exact integer duration, while its
    // /api/search endpoint returns the canonical recording metadata. Search it
    // first so a release-quality suffix such as "(24 Bit)" or a small tagger
    // duration difference does not require a burst of near-duplicate /get
    // requests before the useful lookup is attempted.
    if let request = makeSearchRequest(
      for: track,
      endpoint: endpoint,
      configuration: configuration
    ) {
      switch await performSearchRequest(request, track: track) {
      case .found(let document):
        return document
      case .noMatch, .stop:
        break
      }
    }

    let requestedDuration = max(0, Int(track.duration.rounded()))
    for duration in durationCandidates(
      requestedDuration: requestedDuration,
      parameterName: configuration.durationParameter
    ) {
      var parameters = baseParameters
      if !configuration.durationParameter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        parameters.append((configuration.durationParameter, String(duration)))
      }

      guard let request = makeRequest(
        endpoint: endpoint,
        configuration: configuration,
        parameters: parameters
      ) else { return nil }

      switch await performRequest(request, configuration: configuration) {
      case .found(let document):
        return document
      case .noMatch:
        continue
      case .stop:
        return nil
      }
    }

    return nil
  }

  private struct SearchCandidate: Decodable {
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?
    let instrumental: Bool?
  }

  private enum LookupResult {
    case found(LyricsDocument)
    case noMatch
    case stop
  }

  private static func durationCandidates(
    requestedDuration: Int,
    parameterName: String
  ) -> [Int] {
    guard !parameterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return [requestedDuration]
    }

    return [requestedDuration]
      + (1...durationToleranceSeconds).flatMap { offset in
        [requestedDuration - offset, requestedDuration + offset]
      }
      .filter { $0 >= 0 }
  }

  private static func makeSearchRequest(
    for track: Track,
    endpoint: URL,
    configuration: LyricsProviderConfiguration
  ) -> URLRequest? {
    guard configuration.requestMethod == .get,
          configuration.name.caseInsensitiveCompare("LRCLIB") == .orderedSame,
          endpoint.path.lowercased().hasSuffix("/get") else { return nil }

    var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
    let path = components?.path ?? ""
    guard path.count > 4 else { return nil }
    components?.path = String(path.dropLast(3)) + "search"
    guard let searchEndpoint = components?.url else { return nil }

    let query = [track.artist, track.title, track.album]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    guard !query.isEmpty else { return nil }
    return makeRequest(
      endpoint: searchEndpoint,
      configuration: configuration,
      parameters: [("q", query)]
    )
  }

  private static func makeRequest(
    endpoint: URL,
    configuration: LyricsProviderConfiguration,
    parameters: [(String, String)]
  ) -> URLRequest? {
    var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
    var queryItems = components?.queryItems ?? []
    if configuration.authorizationMode == .queryParameter,
       !configuration.authorizationName.isEmpty {
      queryItems.append(
        URLQueryItem(name: configuration.authorizationName, value: configuration.authorizationToken)
      )
    }
    if configuration.requestMethod == .get {
      queryItems.append(contentsOf: parameters.map {
        URLQueryItem(name: $0.0, value: $0.1)
      })
    }
    components?.queryItems = queryItems
    guard let url = components?.url else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = configuration.requestMethod == .get ? "GET" : "POST"
    request.timeoutInterval = 8
    if !configuration.userAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
    }

    if configuration.requestMethod == .postJSON {
      let body = parameters.reduce(into: [String: String]()) { result, parameter in
        result[parameter.0] = parameter.1
      }
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    switch configuration.authorizationMode {
    case .none, .queryParameter:
      break
    case .bearerHeader:
      request.setValue("Bearer \(configuration.authorizationToken)", forHTTPHeaderField: "Authorization")
    case .customHeader:
      request.setValue(configuration.authorizationToken, forHTTPHeaderField: configuration.authorizationName)
    }
    return request
  }

  private static func performRequest(
    _ request: URLRequest,
    configuration: LyricsProviderConfiguration
  ) async -> LookupResult {
    do {
      for attempt in 0..<2 {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return .stop }
        if http.statusCode == 429 {
          guard attempt == 0 else { return .stop }
          let retryAfter = max(1, min(60, Int(http.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1))
          try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
          continue
        }
        if http.statusCode == 404 {
          return .noMatch
        }
        guard (200..<300).contains(http.statusCode) else { return .stop }

        let result = parse(data: data, configuration: configuration)
        guard !result.syncedLines.isEmpty || !(result.plainLyrics?.isEmpty ?? true) || result.instrumental else {
          return .noMatch
        }
        return .found(result)
      }
      return .stop
    } catch {
      return .stop
    }
  }

  private static func performSearchRequest(
    _ request: URLRequest,
    track: Track
  ) async -> LookupResult {
    do {
      for attempt in 0..<2 {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return .stop }
        if http.statusCode == 429 {
          guard attempt == 0 else { return .stop }
          let retryAfter = max(1, min(60, Int(http.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1))
          try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
          continue
        }
        if http.statusCode == 404 {
          return .noMatch
        }
        guard (200..<300).contains(http.statusCode) else { return .stop }

        let candidates = try JSONDecoder().decode([SearchCandidate].self, from: data)
        guard let candidate = candidates.first(where: { matches($0, track: track) }) else {
          return .noMatch
        }
        let document = makeDocument(
          plainLyrics: candidate.plainLyrics,
          syncedLyrics: candidate.syncedLyrics,
          instrumental: candidate.instrumental ?? false
        )
        guard !document.syncedLines.isEmpty
            || !(document.plainLyrics?.isEmpty ?? true)
            || document.instrumental else {
          return .noMatch
        }
        return .found(document)
      }
      return .stop
    } catch {
      return .stop
    }
  }

  private static func matches(_ candidate: SearchCandidate, track: Track) -> Bool {
    guard normalizedSearchValue(candidate.trackName) == normalizedSearchValue(track.title),
          metadataMatches(candidate.artistName, track.artist) else { return false }

    if !track.album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       !metadataMatches(candidate.albumName, track.album) {
      return false
    }

    guard let candidateDuration = candidate.duration else { return true }
    return abs(candidateDuration.rounded() - track.duration.rounded()) <= Double(durationToleranceSeconds)
  }

  private static func metadataMatches(_ candidate: String?, _ requested: String) -> Bool {
    guard let candidate, !candidate.isEmpty else { return false }
    let normalizedCandidate = normalizedSearchValue(candidate)
    let normalizedRequested = normalizedSearchValue(requested)
    guard !normalizedCandidate.isEmpty, !normalizedRequested.isEmpty else { return false }
    return normalizedCandidate == normalizedRequested
        || normalizedCandidate.contains(normalizedRequested)
        || normalizedRequested.contains(normalizedCandidate)
  }

  private static func normalizedSearchValue(_ value: String?) -> String {
    guard let value else { return "" }
    return value
      .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
      .filter { $0.isLetter || $0.isNumber }
  }

  private static func parse(
    data: Data,
    configuration: LyricsProviderConfiguration
  ) -> LyricsDocument {
    let plainLyrics: String?
    let syncedLyrics: String?
    let instrumental: Bool

    switch configuration.responseFormat {
    case .lrc:
      let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
      plainLyrics = text?.contains("[") == true ? nil : text
      syncedLyrics = text
      instrumental = false
    case .json:
      guard let object = try? JSONSerialization.jsonObject(with: data) else {
        return LyricsDocument(syncedLines: [], plainLyrics: nil, instrumental: false)
      }
      plainLyrics = stringValue(at: configuration.plainResponsePath, in: object)
      syncedLyrics = stringValue(at: configuration.syncedResponsePath, in: object)
      instrumental = boolValue(at: "instrumental", in: object)
    }

    let normalizedPlain = plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedSynced = syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
    return makeDocument(
      plainLyrics: normalizedPlain,
      syncedLyrics: normalizedSynced,
      instrumental: instrumental
    )
  }

  private static func makeDocument(
    plainLyrics: String?,
    syncedLyrics: String?,
    instrumental: Bool
  ) -> LyricsDocument {
    LyricsDocument(
      syncedLines: parseLRC(syncedLyrics),
      plainLyrics: plainLyrics?.isEmpty == true ? nil : plainLyrics,
      instrumental: instrumental
    )
  }

  private static func stringValue(at path: String, in object: Any) -> String? {
    let components = path
      .split(separator: ".")
      .map(String.init)
      .filter { !$0.isEmpty }
    guard !components.isEmpty else { return nil }

    var current: Any = object
    for component in components {
      guard let dictionary = current as? [String: Any], let next = dictionary[component] else {
        return nil
      }
      current = next
    }
    return current as? String
  }

  private static func boolValue(at path: String, in object: Any) -> Bool {
    guard let value = stringValue(at: path, in: object) else {
      var current: Any = object
      for component in path.split(separator: ".").map(String.init) {
        guard let dictionary = current as? [String: Any], let next = dictionary[component] else { return false }
        current = next
      }
      return current as? Bool ?? false
    }
    return value.lowercased() == "true" || value == "1"
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
  @Published private(set) var importErrorMessage: String?

  private var cache: [String: LyricsDocument?] = [:]
  private var requestTask: Task<Void, Never>?
  private var importTask: Task<Void, Never>?
  private var requestedKey = ""
  private var lastPlaybackRestartID: Int?

  func load(
    for track: Track?,
    provider: LyricsProviderConfiguration?,
    searchLocalSiblingFile: Bool = false
  ) {
    requestTask?.cancel()
    guard let track else {
      requestedKey = ""
      document = nil
      isLoading = false
      return
    }

    let providerKey = provider?.cacheKey ?? "none"
    let localKey = Self.localKey(for: track)
    let key = [localKey, providerKey, String(searchLocalSiblingFile)].joined(separator: "|")
    requestedKey = key

    document = nil
    isLoading = true
    requestTask = Task { [weak self] in
      let localDocument = await LyricsService.localDocument(
        for: track,
        searchSiblingFile: searchLocalSiblingFile
      )
      guard !Task.isCancelled else { return }
      guard let self, self.requestedKey == key else { return }

      if let localDocument {
        self.document = localDocument
        self.isLoading = false
        ResonanceDiagnostics.shared.recordDeferred(
          "lyrics.local.loaded",
          details: [
            "synced": String(localDocument.hasSyncedLyrics),
            "siblingSearch": String(searchLocalSiblingFile)
          ]
        )
        return
      }

      guard let provider, provider.isUsable else {
        self.document = nil
        self.isLoading = false
        return
      }

      let remoteKey = Self.key(for: track, provider: provider)
      if let cached = self.cache[remoteKey] {
        self.document = cached
        self.isLoading = false
        return
      }

      let result = await LyricsService.fetch(for: track, configuration: provider)
      guard !Task.isCancelled else { return }
      guard self.requestedKey == key else { return }
      self.cache[remoteKey] = result
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

  /// Revalidates local lyric files after playback restarts. The restart ID is
  /// shared by layered Now Playing views so one playback event results in one
  /// detached file read.
  func reloadForPlayback(
    restartID: Int,
    track: Track?,
    provider: LyricsProviderConfiguration?,
    searchLocalSiblingFile: Bool = false
  ) {
    guard let track, track.fileURL?.isFileURL == true else { return }
    guard lastPlaybackRestartID != restartID else { return }
    lastPlaybackRestartID = restartID
    ResonanceDiagnostics.shared.recordDeferred("lyrics.local.rescan.begin")
    load(
      for: track,
      provider: provider,
      searchLocalSiblingFile: searchLocalSiblingFile
    )
  }

  func importLRC(from url: URL, for track: Track) {
    importTask?.cancel()
    requestTask?.cancel()
    requestedKey = ""
    document = nil
    isLoading = true
    importErrorMessage = nil

    let didStartAccessing = url.startAccessingSecurityScopedResource()
    importTask = Task { [weak self] in
      let data = await Task.detached(priority: .userInitiated) {
        try? Data(contentsOf: url)
      }.value
      if didStartAccessing {
        url.stopAccessingSecurityScopedResource()
      }

      guard let self else { return }
      guard let data, let document = LyricsService.document(fromLRCData: data) else {
        self.isLoading = false
        self.importErrorMessage = "The selected file does not contain readable LRC lyrics."
        return
      }

      do {
        try LyricsService.saveLocalOverride(data, for: track)
        self.document = document
        self.isLoading = false
        ResonanceDiagnostics.shared.recordDeferred(
          "lyrics.local.imported",
          details: ["synced": String(document.hasSyncedLyrics)]
        )
      } catch {
        self.isLoading = false
        self.importErrorMessage = "The selected lyrics file could not be saved in MeiKyo."
      }
    }
  }

  func dismissImportError() {
    importErrorMessage = nil
  }

  private static func key(for track: Track, provider: LyricsProviderConfiguration) -> String {
    [track.artist, track.albumArtist, track.album, track.title, String(Int(track.duration.rounded())), provider.cacheKey]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .joined(separator: "|")
  }

  private static func localKey(for track: Track) -> String {
    if let fileURL = track.fileURL, fileURL.isFileURL {
      return "file:\(fileURL.standardizedFileURL.path)"
    }
    return "id:\(track.id.uuidString)"
  }
}
