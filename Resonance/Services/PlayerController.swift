@preconcurrency import AVFoundation
import MediaPlayer
import UIKit

enum RepeatMode: String, CaseIterable, Identifiable {
  case off = "Off"
  case all = "Repeat All"
  case one = "Repeat One"

  var id: String { rawValue }
  var systemImage: String {
    switch self {
    case .off, .all: return "repeat"
    case .one: return "repeat.1"
    }
  }
}

enum SleepTimerOption: String, CaseIterable, Identifiable {
  case off = "Off"
  case fifteenMinutes = "15 Minutes"
  case thirtyMinutes = "30 Minutes"
  case fortyFiveMinutes = "45 Minutes"
  case sixtyMinutes = "60 Minutes"
  case endOfTrack = "End of Track"

  var id: String { rawValue }
  var interval: TimeInterval? {
    switch self {
    case .off, .endOfTrack: return nil
    case .fifteenMinutes: return 15 * 60
    case .thirtyMinutes: return 30 * 60
    case .fortyFiveMinutes: return 45 * 60
    case .sixtyMinutes: return 60 * 60
    }
  }
}

struct PlaybackBookmark: Identifiable, Codable, Hashable, Sendable {
  let id: UUID
  let trackID: UUID
  let time: TimeInterval
  let createdAt: Date

  init(id: UUID = UUID(), trackID: UUID, time: TimeInterval, createdAt: Date = Date()) {
    self.id = id
    self.trackID = trackID
    self.time = time
    self.createdAt = createdAt
  }
}

/// High-frequency playback progress is kept separate from the controller's
/// normal state so catalog and settings views do not invalidate on every timer
/// tick. Only progress-aware views should observe this object.
@MainActor
final class PlaybackProgress: ObservableObject {
  @Published private(set) var elapsed = 0.0

  fileprivate func update(elapsed: Double) {
    self.elapsed = elapsed
  }
}

private struct PreparedNowPlayingArtwork: Sendable {
  let imageData: Data
  let boundsSize: CGSize
}

@MainActor
final class PlayerController: NSObject, ObservableObject {
  let progress = PlaybackProgress()
  @Published private(set) var currentTrack: Track?
  @Published private(set) var isPlaying = false
  private(set) var elapsed = 0.0 {
    didSet { progress.update(elapsed: elapsed) }
  }
  @Published private(set) var duration = 0.0
  // Meter values are used for diagnostics and audio-state decisions. Keeping
  // them off PlayerController.objectWillChange prevents every visible track
  // row from rebuilding at the 120 ms playback cadence.
  private(set) var meterLevel = 0.0
  @Published private(set) var queue: [Track] = []
  @Published private(set) var currentQueueIndex = 0
  @Published var shuffleEnabled = false
  @Published var repeatMode: RepeatMode = .off
  @Published var volume = 1.0 {
    didSet {
      let clamped = Float(min(max(volume, 0), 1))
      switch activeBackend {
      case .gapless: gaplessEngine.volume = clamped
      case .legacy: audioPlayer?.volume = clamped
      case .remote: activeRemotePlayer?.volume = clamped
      case .none: break
      }
    }
  }
  @Published private(set) var sleepTimerOption: SleepTimerOption = .off
  @Published private(set) var sleepTimerRemaining: TimeInterval = 0
  @Published private(set) var bookmarks: [PlaybackBookmark] = []
  @Published private(set) var playbackEngineStatus = "Ready"
  @Published private(set) var preloadedTrackTitle: String?
  @Published private(set) var preloadDetail = "No track preloaded"
  @Published private(set) var audioFormatStatus = "Stereo output ready"
  @Published private(set) var downmixRoutingStatus = "Automatic stereo routing"
  @Published private(set) var networkBufferStatus = "No remote stream active"
  @Published private(set) var playbackStartupDiagnostic =
    UserDefaults.standard.string(forKey: "resonance.lastPlaybackStartupStage") ?? "No playback attempt recorded"
  @Published private(set) var playbackRuntimeDiagnostic =
    UserDefaults.standard.string(forKey: "resonance.lastPlaybackRuntimeStage") ?? "No playback runtime stage recorded"

  var onTrackStarted: (@MainActor (Track) -> Void)?
  var onRuntimeError: (@MainActor (_ source: String, _ message: String) -> Void)?

  private enum ActiveBackend { case none, gapless, legacy, remote }

  private var sourceQueue: [Track] = []
  private var activeBackend: ActiveBackend = .none
  private var audioPlayer: AVAudioPlayer?
  private var remotePlayer: AVPlayer?
  private var remoteItemTracks: [ObjectIdentifier: Track] = [:]
  private var remotePreloadPlayer: AVPlayer?
  private var remotePreloadItem: AVPlayerItem?
  private var remotePreloadTrack: Track?
  private var remotePreloadReady = false
  private var remotePreloadTask: Task<Void, Never>?
  private var remoteGaplessHandoffTask: Task<Void, Never>?
  private var remoteExperimentalSession = false
  private lazy var remoteObserver = RemotePlayerObserver(owner: self)
  private var playbackTimerTask: Task<Void, Never>?
  private var sleepTimerTask: Task<Void, Never>?
  private var lastNowPlayingProgressUpdate = 0.0
  private var hasRecordedFirstPlaybackTick = false
  private var playbackAnchorDate: Date?
  private var playbackAnchorElapsed = 0.0
  private var playbackGeneration = 0
  private var playbackTimerTickCount = 0
  private var nowPlayingArtworkTask: Task<Void, Never>?
  private var nowPlayingArtworkTrackID: UUID?
  private var cachedNowPlayingArtworkTrackID: UUID?
  private var cachedNowPlayingArtwork: PreparedNowPlayingArtwork?
  private var preloadedTrackID: UUID?
  private var remoteSeekInFlight = false
  private var remoteSeekRequestID = 0
  private var pendingRemoteSeekPosition: Double?
  private var remoteClockHoldPosition: Double?
  private var remoteClockHoldStartedAt: Date?
  private var remoteClockHoldWasPlaying = false
  private var remoteEndHandledTrackID: UUID?
  private var lastRemoteBufferStatusPublicationDate = Date.distantPast
  private var engineDurations: [UUID: TimeInterval] = [:]
  private var engineChannelCounts: [UUID: AVAudioChannelCount] = [:]
  private var partialPreloadFrames: [UUID: AVAudioFramePosition] = [:]
  private lazy var audioDelegate = AudioPlayerDelegateProxy(owner: self)
  private lazy var gaplessEngine = makeGaplessEngine()
  private var gaplessDisabledForSession = false

  // AVPlayer cannot make two independent network decoders sample-contiguous.
  // Start the warmed next player slightly before the old item ends and ramp
  // between the two outputs so decoder/startup latency cannot become silence.
  private let remoteGaplessHandoffDuration: TimeInterval = 0.35
  private let remoteClockHoldDuration: TimeInterval = 0.8

  private var activeRemotePlayer: AVPlayer? {
    remotePlayer
  }

  private var remoteGaplessExperimentalEnabled: Bool {
    UserDefaults.standard.bool(forKey: "streamingGaplessExperimental")
  }

  private func makeGaplessEngine() -> GaplessAudioEngine {
    let engine = GaplessAudioEngine()
    engine.setCompletionHandler { [weak self] trackID, generation in
      Task { @MainActor [weak self] in
        self?.handleGaplessTrackFinished(trackID: trackID, generation: generation)
      }
    }
    engine.volume = Float(min(max(volume, 0), 1))
    return engine
  }

  private func quarantineGaplessEngineAfterMatrixFailure() {
    // Keep the failed engine instance alive but disconnected for the remainder
    // of this process. This avoids resetting or deallocating a partially
    // configured Matrix Mixer while playback falls back to AVAudioPlayer.
    gaplessEngine.setCompletionHandler(nil)
    gaplessEngine.abandonFailedPreparation()
    gaplessDisabledForSession = true
  }

  override init() {
    bookmarks = Self.loadBookmarks()
    super.init()
    configureSession()
    configureRemoteCommands()
  }

  var upcomingTracks: [Track] {
    guard !queue.isEmpty, currentQueueIndex + 1 < queue.count else { return [] }
    return Array(queue[(currentQueueIndex + 1)...])
  }

  var currentTrackBookmarks: [PlaybackBookmark] {
    guard let currentTrack else { return [] }
    return
      bookmarks
      .filter { $0.trackID == currentTrack.id }
      .sorted { $0.time < $1.time }
  }

  var sleepTimerLabel: String {
    switch sleepTimerOption {
    case .off: return "Off"
    case .endOfTrack: return "End of Track"
    default:
      let remaining = max(0, Int(sleepTimerRemaining.rounded(.up)))
      return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
  }

  func artworkData(for track: Track) -> Data? {
    if let artwork = track.artworkData { return artwork }
    return artworkSource(for: track)?.artworkData
  }

  func artworkIsEmbedded(for track: Track) -> Bool {
    if track.artworkData != nil { return track.artworkIsEmbedded }
    return artworkSource(for: track)?.artworkIsEmbedded ?? true
  }

  func play(_ track: Track, in tracks: [Track]) {
    guard tracks.contains(track) else { return }
    sourceQueue = tracks

    if shuffleEnabled {
      let remaining = tracks.filter { $0.id != track.id }.shuffled()
      queue = [track] + remaining
      currentQueueIndex = 0
    } else {
      queue = tracks
      currentQueueIndex = tracks.firstIndex(of: track) ?? 0
    }

    _ = loadAndPlay(track)
  }

  func shuffleAndPlay(_ tracks: [Track]) {
    let candidates = uniqueTracks(tracks)
    guard let first = candidates.randomElement() else { return }
    shuffleEnabled = true
    play(first, in: candidates)
  }

  func playQueueItem(_ track: Track) {
    guard let targetIndex = queue.firstIndex(of: track) else { return }
    _ = loadAndPlay(track, at: targetIndex)
  }

  /// Inserts tracks immediately after the currently playing item. Existing
  /// occurrences are removed from the upcoming queue first so a quick action
  /// never creates accidental duplicates.
  func playNext(_ tracks: [Track]) {
    let requested = uniqueTracks(tracks).filter { $0.id != currentTrack?.id }
    guard !requested.isEmpty else { return }

    guard currentTrack != nil, !queue.isEmpty else {
      if let first = requested.first { play(first, in: requested) }
      return
    }

    let requestedIDs = Set(requested.map(\.id))
    let played = Array(queue.prefix(currentQueueIndex + 1))
    let remaining = queue.dropFirst(currentQueueIndex + 1).filter { !requestedIDs.contains($0.id) }
    queue = played + requested + remaining

    sourceQueue.removeAll { requestedIDs.contains($0.id) }
    if let currentTrack,
      let sourceIndex = sourceQueue.firstIndex(where: { $0.id == currentTrack.id })
    {
      let insertionIndex = min(sourceIndex + 1, sourceQueue.count)
      sourceQueue.insert(contentsOf: requested, at: insertionIndex)
    } else {
      let existingSourceIDs = Set(sourceQueue.map(\.id))
      sourceQueue.append(contentsOf: requested.filter { !existingSourceIDs.contains($0.id) })
    }
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  /// Appends tracks to the end of the playback queue while preserving their
  /// requested order and omitting anything already queued.
  func addToQueue(_ tracks: [Track]) {
    let requested = uniqueTracks(tracks)
    guard !requested.isEmpty else { return }

    guard currentTrack != nil, !queue.isEmpty else {
      if let first = requested.first { play(first, in: requested) }
      return
    }

    let queuedIDs = Set(queue.map(\.id))
    let additions = requested.filter { !queuedIDs.contains($0.id) }
    guard !additions.isEmpty else { return }
    queue.append(contentsOf: additions)

    let sourceIDs = Set(sourceQueue.map(\.id))
    sourceQueue.append(contentsOf: additions.filter { !sourceIDs.contains($0.id) })
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  func play() {
    guard currentTrack != nil, !isPlaying else { return }
    switch activeBackend {
    case .gapless:
      do {
        try gaplessEngine.play()
      } catch {
        playbackEngineStatus = "Audio engine could not resume"
        return
      }
    case .legacy:
      guard audioPlayer?.play() == true else { return }
    case .remote:
      guard let activeRemotePlayer else { return }
      if remoteGaplessExperimentalEnabled {
        activeRemotePlayer.playImmediately(atRate: 1)
      } else {
        activeRemotePlayer.play()
      }
      if remoteClockHoldPosition != nil {
        remoteClockHoldWasPlaying = true
        remoteClockHoldStartedAt = Date()
      }
    case .none:
      return
    }
    playbackAnchorDate = Date()
    playbackAnchorElapsed = elapsed
    isPlaying = true
    startPlaybackTimer()
    updateNowPlaying()
  }

  func pause() {
    guard isPlaying else { return }
    updateElapsedFromClock()
    switch activeBackend {
    case .gapless: gaplessEngine.pause()
    case .legacy: audioPlayer?.pause()
    case .remote: activeRemotePlayer?.pause()
    case .none: break
    }
    playbackAnchorDate = nil
    playbackAnchorElapsed = elapsed
    if activeBackend == .remote {
      remoteClockHoldPosition = elapsed
      remoteClockHoldStartedAt = Date()
      remoteClockHoldWasPlaying = false
    }
    isPlaying = false
    updateNowPlaying()
  }

  func toggle() {
    isPlaying ? pause() : play()
  }

  func next() {
    guard !queue.isEmpty else { return }
    if let targetIndex = nextQueueIndex(after: currentQueueIndex) {
      _ = loadAndPlay(queue[targetIndex], at: targetIndex)
    } else {
      stop()
    }
  }

  func previous() {
    if elapsed > 3 {
      seek(to: 0)
      return
    }
    previousTrack()
  }

  /// Moves directly to the preceding queue item. This is used by the Now
  /// Playing swipe gesture, where a right swipe always means previous track.
  func previousTrack() {
    guard !queue.isEmpty else { return }
    let targetIndex = currentQueueIndex - 1
    if queue.indices.contains(targetIndex) {
      _ = loadAndPlay(queue[targetIndex], at: targetIndex)
    } else if repeatMode == .all, let last = queue.last {
      _ = loadAndPlay(last, at: queue.count - 1)
    } else {
      seek(to: 0)
    }
  }

  func skip(by interval: TimeInterval) {
    guard currentTrack != nil else { return }
    let basePosition: Double
    if activeBackend == .remote, let pendingRemoteSeekPosition {
      basePosition = pendingRemoteSeekPosition
    } else {
      basePosition = elapsed
    }
    seek(to: basePosition + interval)
  }

  func toggleShuffle() {
    shuffleEnabled.toggle()
    guard let currentTrack else { return }

    if shuffleEnabled {
      let alreadyPlayed = Array(queue.prefix(currentQueueIndex + 1))
      let upcoming = Array(queue.dropFirst(currentQueueIndex + 1)).shuffled()
      queue = alreadyPlayed + upcoming
    } else {
      let retainedIDs = Set(queue.map(\.id))
      let restoredQueue = sourceQueue.filter { retainedIDs.contains($0.id) }
      if let restoredIndex = restoredQueue.firstIndex(of: currentTrack) {
        queue = restoredQueue
        currentQueueIndex = restoredIndex
      }
    }
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  func cycleRepeatMode() {
    switch repeatMode {
    case .off: repeatMode = .all
    case .all: repeatMode = .one
    case .one: repeatMode = .off
    }
    refreshPreloadedTrackAfterQueueChange()
  }

  func removeUpcoming(atOffsets offsets: IndexSet) {
    let start = currentQueueIndex + 1
    let absoluteIndices = offsets.map { start + $0 }.sorted(by: >)
    let removedIDs = Set(
      absoluteIndices.compactMap { queue.indices.contains($0) ? queue[$0].id : nil })
    for index in absoluteIndices where queue.indices.contains(index) {
      queue.remove(at: index)
    }
    sourceQueue.removeAll { removedIDs.contains($0.id) }
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  func moveUpcoming(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    var upcoming = upcomingTracks
    let validOffsets = offsets.filter { upcoming.indices.contains($0) }.sorted()
    guard !validOffsets.isEmpty else { return }

    let movingTracks = validOffsets.map { upcoming[$0] }
    for index in validOffsets.reversed() {
      upcoming.remove(at: index)
    }

    let removedBeforeDestination = validOffsets.filter { $0 < destination }.count
    let adjustedDestination = min(max(0, destination - removedBeforeDestination), upcoming.count)
    upcoming.insert(contentsOf: movingTracks, at: adjustedDestination)

    queue = Array(queue.prefix(currentQueueIndex + 1)) + upcoming
    sourceQueue = queue
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  func clearUpcoming() {
    guard !queue.isEmpty else { return }
    queue = Array(queue.prefix(currentQueueIndex + 1))
    let retainedIDs = Set(queue.map(\.id))
    sourceQueue.removeAll { !retainedIDs.contains($0.id) }
    updateNowPlaying()
    refreshPreloadedTrackAfterQueueChange()
  }

  func addBookmarkAtCurrentPosition() {
    guard let currentTrack, duration > 0 else { return }
    let roundedTime = min(max(0, elapsed.rounded()), max(0, duration - 0.5))
    let alreadyExists = bookmarks.contains {
      $0.trackID == currentTrack.id && abs($0.time - roundedTime) < 2
    }
    guard !alreadyExists else { return }
    bookmarks.append(PlaybackBookmark(trackID: currentTrack.id, time: roundedTime))
    persistBookmarks()
  }

  func seek(to bookmark: PlaybackBookmark) {
    guard bookmark.trackID == currentTrack?.id else { return }
    seek(to: bookmark.time)
  }

  func removeBookmarks(atOffsets offsets: IndexSet) {
    let visible = currentTrackBookmarks
    let ids = Set(offsets.compactMap { visible.indices.contains($0) ? visible[$0].id : nil })
    guard !ids.isEmpty else { return }
    bookmarks.removeAll { ids.contains($0.id) }
    persistBookmarks()
  }

  func removeBookmark(_ bookmark: PlaybackBookmark) {
    bookmarks.removeAll { $0.id == bookmark.id }
    persistBookmarks()
  }

  func setSleepTimer(_ option: SleepTimerOption) {
    sleepTimerTask?.cancel()
    sleepTimerTask = nil
    sleepTimerOption = option
    sleepTimerRemaining = option.interval ?? 0

    guard let interval = option.interval else { return }
    let deadline = Date().addingTimeInterval(interval)
    sleepTimerTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, let self else { return }
        self.sleepTimerRemaining = max(0, deadline.timeIntervalSinceNow)
        if self.sleepTimerRemaining <= 0 {
          self.sleepTimerTask = nil
          self.sleepTimerOption = .off
          self.stop()
          return
        }
      }
    }
  }

  func stop() {
    playbackGeneration += 1
    playbackTimerTask?.cancel()
    playbackTimerTask = nil
    sleepTimerTask?.cancel()
    sleepTimerTask = nil
    tearDownActiveBackend()
    activeBackend = .none
    isPlaying = false
    elapsed = 0
    duration = 0
    meterLevel = 0
    currentTrack = nil
    queue = []
    sourceQueue = []
    currentQueueIndex = 0
    sleepTimerOption = .off
    sleepTimerRemaining = 0
    lastNowPlayingProgressUpdate = 0
    playbackAnchorDate = nil
    playbackAnchorElapsed = 0
    preloadedTrackID = nil
    preloadedTrackTitle = nil
    preloadDetail = "No track preloaded"
    audioFormatStatus = "Stereo output ready"
    downmixRoutingStatus = "Automatic stereo routing"
    networkBufferStatus = "No remote stream active"
    engineDurations.removeAll()
    engineChannelCounts.removeAll()
    partialPreloadFrames.removeAll()
    playbackEngineStatus = "Ready"
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  func seek(to value: Double) {
    guard let currentTrack else { return }
    let clamped = safeSeekPosition(value, duration: duration)
    ResonanceDiagnostics.shared.record(
      "playback.seek.begin",
      details: [
        "backend": activeBackendLabel,
        "position": String(format: "%.3f", clamped),
        "duration": String(format: "%.3f", duration)
      ]
    )

    switch activeBackend {
    case .gapless:
      let wasPlaying = isPlaying
      let succeeded = loadAndPlay(
        currentTrack,
        at: currentQueueIndex,
        startTime: clamped,
        autoPlay: wasPlaying,
        notifyTrackStarted: false
      )
      ResonanceDiagnostics.shared.record(
        "playback.seek.completed",
        details: [
          "backend": "gapless",
          "success": String(succeeded),
          "position": String(format: "%.3f", clamped)
        ]
      )
      if succeeded {
        elapsed = clamped
        playbackAnchorElapsed = clamped
        if !wasPlaying { pause() }
      }
    case .legacy:
      guard let audioPlayer else { return }
      audioPlayer.currentTime = safeSeekPosition(clamped, duration: audioPlayer.duration)
      elapsed = audioPlayer.currentTime
      playbackAnchorElapsed = elapsed
      playbackAnchorDate = isPlaying ? Date() : nil
      updateNowPlayingProgress()
      ResonanceDiagnostics.shared.record(
        "playback.seek.completed",
        details: [
          "backend": "legacy",
          "success": "true",
          "position": String(format: "%.3f", elapsed)
        ]
      )
    case .remote:
      guard let activeRemotePlayer else { return }
      let wasPlaying = isPlaying
      let target = CMTime(seconds: clamped, preferredTimescale: 600)
      remoteSeekRequestID &+= 1
      let requestID = remoteSeekRequestID
      pendingRemoteSeekPosition = clamped
      remoteSeekInFlight = true
      remoteClockHoldPosition = clamped
      remoteClockHoldStartedAt = Date()
      remoteClockHoldWasPlaying = wasPlaying
      elapsed = clamped
      playbackAnchorElapsed = clamped
      playbackAnchorDate = isPlaying ? Date() : nil
      updateNowPlayingProgress()
      let generation = playbackGeneration
      activeRemotePlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) {
        [weak self, weak activeRemotePlayer] finished in
        Task { @MainActor [weak self, weak activeRemotePlayer] in
          guard let self,
            let activeRemotePlayer,
            self.activeBackend == .remote,
            self.activeRemotePlayer === activeRemotePlayer,
            self.playbackGeneration == generation,
            self.remoteSeekRequestID == requestID
          else { return }

          self.remoteSeekInFlight = false
          self.pendingRemoteSeekPosition = nil
          guard finished else {
            self.clearRemoteClockHold()
            self.updateElapsedFromClock()
            self.resumeRemotePlaybackAfterSeek(
              activeRemotePlayer,
              wasPlaying: wasPlaying
            )
            self.updateNowPlayingProgress()
            ResonanceDiagnostics.shared.recordDeferred(
              "remote.player.seek.completed",
              details: ["finished": String(finished)]
            )
            return
          }

          let actual = activeRemotePlayer.currentTime().seconds
          // AVPlayer can report its pre-seek clock briefly after a successful
          // completion. The requested position is authoritative for the UI;
          // retain the raw clock only for diagnostics.
          self.elapsed = self.clampedRemoteElapsed(clamped)
          self.playbackAnchorElapsed = self.elapsed
          self.playbackAnchorDate = self.isPlaying ? Date() : nil
          self.remoteClockHoldPosition = self.elapsed
          self.remoteClockHoldStartedAt = Date()
          self.remoteClockHoldWasPlaying = wasPlaying
          self.resumeRemotePlaybackAfterSeek(
            activeRemotePlayer,
            wasPlaying: wasPlaying
          )
          self.updateNowPlayingProgress()
          ResonanceDiagnostics.shared.recordDeferred(
            "remote.player.seek.completed",
            details: [
              "finished": String(finished),
              "target": String(format: "%.3f", clamped),
              "actual": actual.isFinite ? String(format: "%.3f", actual) : "invalid"
            ]
          )
        }
      }
    case .none:
      break
    }
  }

  private func resumeRemotePlaybackAfterSeek(_ player: AVPlayer, wasPlaying: Bool) {
    guard wasPlaying, isPlaying else { return }
    if remoteExperimentalSession {
      player.playImmediately(atRate: 1)
    } else {
      player.play()
    }
    playbackAnchorElapsed = elapsed
    playbackAnchorDate = Date()
    ResonanceDiagnostics.shared.recordDeferred(
      "remote.player.seek.resume",
      details: [
        "experimental": String(remoteExperimentalSession),
        "timeControlStatus": String(describing: player.timeControlStatus)
      ]
    )
  }

  /// Re-reads the persisted preload settings and rebuilds the future schedule
  /// without changing the selected track or its visible play position.
  func refreshNowPlayingMetadata() {
    updateNowPlaying()
  }

  func refreshPlaybackConfiguration() {
    guard let currentTrack else { return }
    if activeBackend == .remote {
      activeRemotePlayer?.currentItem?.preferredForwardBufferDuration = remoteForwardBufferDuration(for: currentTrack)
      updateRemoteBufferStatus()
      return
    }
    guard activeBackend == .gapless else { return }
    updateElapsedFromClock()
    let wasPlaying = isPlaying
    _ = loadAndPlay(
      currentTrack,
      at: currentQueueIndex,
      startTime: elapsed,
      autoPlay: wasPlaying,
      notifyTrackStarted: false
    )
  }

  func refreshRemoteGaplessConfiguration() {
    guard activeBackend == .remote, let currentTrack else { return }
    updateElapsedFromClock()
    let wasPlaying = isPlaying
    _ = loadAndPlay(
      currentTrack,
      at: currentQueueIndex,
      startTime: elapsed,
      autoPlay: wasPlaying,
      notifyTrackStarted: false
    )
  }

  private func markPlaybackStartupStage(_ stage: String) {
    ResonanceDiagnostics.shared.recordDeferred(
      "playback.startup.stage",
      details: ["stage": stage, "generation": String(playbackGeneration)]
    )
    playbackStartupDiagnostic = stage
    DispatchQueue.global(qos: .utility).async {
      UserDefaults.standard.set(stage, forKey: "resonance.lastPlaybackStartupStage")
    }
  }

  private func markPlaybackRuntimeStage(_ stage: String) {
    ResonanceDiagnostics.shared.recordDeferred(
      "playback.runtime.stage",
      details: ["stage": stage, "generation": String(playbackGeneration)]
    )
    playbackRuntimeDiagnostic = stage
    DispatchQueue.global(qos: .utility).async {
      UserDefaults.standard.set(stage, forKey: "resonance.lastPlaybackRuntimeStage")
    }
  }

  private func reportRuntimeError(source: String = "Playback", _ message: String) {
    let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    onRuntimeError?(source, cleaned)
  }

  /// Stops only the backend that is currently active. This avoids lazily
  /// constructing and resetting the local AVAudioEngine for remote playback,
  /// and avoids the redundant double-reset that previously occurred before
  /// every local prepare operation.
  private func tearDownActiveBackend() {
    switch activeBackend {
    case .gapless:
      gaplessEngine.stop(resetEngine: true)
    case .legacy:
      audioPlayer?.delegate = nil
      audioPlayer?.stop()
      audioPlayer = nil
    case .remote:
      remoteGaplessHandoffTask?.cancel()
      remoteGaplessHandoffTask = nil
      remoteObserver.stop()
      remotePreloadTask?.cancel()
      remotePreloadTask = nil
      remotePreloadPlayer?.cancelPendingPrerolls()
      remotePreloadPlayer?.pause()
      remotePreloadPlayer?.replaceCurrentItem(with: nil)
      remotePreloadPlayer = nil
      remotePreloadItem = nil
      remotePreloadTrack = nil
      remotePreloadReady = false
      activeRemotePlayer?.cancelPendingPrerolls()
      activeRemotePlayer?.pause()
      remotePlayer?.replaceCurrentItem(with: nil)
      remotePlayer = nil
      remoteItemTracks.removeAll()
      remoteExperimentalSession = false
      remoteSeekInFlight = false
      remoteSeekRequestID &+= 1
      pendingRemoteSeekPosition = nil
      remoteEndHandledTrackID = nil
      clearRemoteClockHold()
    case .none:
      break
    }  }

  @discardableResult
  private func loadAndPlay(
    _ track: Track,
    at targetIndex: Int? = nil,
    startTime: TimeInterval = 0,
    autoPlay: Bool = true,
    notifyTrackStarted: Bool = true
  ) -> Bool {
    guard let url = track.fileURL else {
      clearUnplayableTrack()
      return false
    }
    if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
      clearUnplayableTrack()
      return false
    }
    if !url.isFileURL && !(url.scheme == "http" || url.scheme == "https") {
      clearUnplayableTrack()
      return false
    }

    let resolvedIndex = targetIndex ?? queue.firstIndex(of: track) ?? currentQueueIndex
    ResonanceDiagnostics.shared.record(
      "playback.request",
      details: [
        "backend": url.isFileURL ? "local" : "remote",
        "autoPlay": String(autoPlay),
        "queueCount": String(queue.count),
        "startTime": String(format: "%.3f", startTime)
      ]
    )
    markPlaybackStartupStage(url.isFileURL ? "Local request accepted" : "Remote request accepted")
    playbackGeneration += 1
    let generation = playbackGeneration
    playbackTimerTask?.cancel()
    playbackTimerTask = nil
    tearDownActiveBackend()
    markPlaybackStartupStage("Previous playback backend stopped")
    activeBackend = .none
    isPlaying = false
    elapsed = max(0, startTime)
    playbackAnchorElapsed = elapsed
    playbackAnchorDate = nil
    meterLevel = 0
    preloadedTrackID = nil
    preloadedTrackTitle = nil
    engineDurations.removeAll()
    engineChannelCounts.removeAll()
    partialPreloadFrames.removeAll()
    preloadDetail = "No track preloaded"
    audioFormatStatus = "Stereo output ready"
    downmixRoutingStatus = "Automatic stereo routing"
    networkBufferStatus = "No remote stream active"
    lastRemoteBufferStatusPublicationDate = .distantPast
    playbackTimerTickCount = 0
    remoteGaplessHandoffTask?.cancel()
    remoteGaplessHandoffTask = nil
    clearRemoteClockHold()

    if !url.isFileURL {
      markPlaybackStartupStage("Creating stable remote player")
      return loadWithRemotePlayer(
        track,
        url: url,
        at: resolvedIndex,
        startTime: startTime,
        autoPlay: autoPlay,
        notifyTrackStarted: notifyTrackStarted
      )
    }

    if gaplessDisabledForSession {
      markPlaybackStartupStage("Using compatibility player after a matrix failure")
      playbackEngineStatus = "Compatibility fallback — gapless disabled until relaunch"
      return loadWithLegacyPlayer(
        track,
        url: url,
        at: resolvedIndex,
        startTime: startTime,
        autoPlay: autoPlay,
        notifyTrackStarted: notifyTrackStarted,
        successfulStartupStage: "Compatibility playback started successfully with gapless disabled"
      )
    }

    let following = preloadCandidate(after: resolvedIndex)
    do {
      markPlaybackStartupStage("Preparing local audio engine")
      let preparationStartedAt = Date()
      let prepared = try gaplessEngine.prepare(
        currentTrackID: track.id,
        currentURL: url,
        startTime: startTime,
        followingTrackID: following?.id,
        followingURL: following?.fileURL,
        preloadBudgetBytes: localPreloadBudgetBytes,
        generation: generation
      )
      gaplessEngine.volume = Float(min(max(volume, 0), 1))
      activeBackend = .gapless
      currentQueueIndex = resolvedIndex
      currentTrack = track
      duration = prepared.current.duration
      engineDurations[track.id] = prepared.current.duration
      engineChannelCounts[track.id] = prepared.current.channelCount
      audioFormatStatus = Self.audioFormatDescription(
        sourceChannels: prepared.current.channelCount,
        outputChannels: gaplessEngine.outputChannelCount
      )
      downmixRoutingStatus = gaplessEngine.downmixRoutingDescription
      ResonanceDiagnostics.shared.record(
        "playback.gapless.prepared",
        details: [
          "sourceChannels": String(prepared.current.channelCount),
          "sourceSampleRate": String(format: "%.0f", prepared.sourceSampleRate),
          "sourceFrames": String(prepared.sourceFrameLength),
          "duration": String(format: "%.3f", prepared.current.duration),
          "graphSampleRate": String(format: "%.0f", prepared.graphSampleRate),
          "outputSampleRate": String(format: "%.0f", prepared.outputSampleRate),
          "preparationMs": String(format: "%.1f", Date().timeIntervalSince(preparationStartedAt) * 1000),
          "engineRunning": String(gaplessEngine.isEngineRunning),
          "playerNodePlaying": String(gaplessEngine.isPlaying),
          "meter": String(format: "%.5f", gaplessEngine.meterLevel)
        ]
      )
      if let following, let followingSchedule = prepared.following {
        preloadedTrackID = following.id
        preloadedTrackTitle = following.title
        engineDurations[following.id] = followingSchedule.duration
        engineChannelCounts[following.id] = followingSchedule.channelCount
        if let remainingFrame = followingSchedule.remainingStartFrame {
          partialPreloadFrames[following.id] = remainingFrame
          preloadDetail = "Opening segment scheduled; remainder streams from disk"
          playbackEngineStatus = "Gapless ready — partial preload"
        } else {
          preloadDetail = "Complete next track scheduled"
          playbackEngineStatus = "Gapless ready"
        }
      } else if following != nil {
        preloadDetail = "The next file could not be opened by the gapless engine"
        playbackEngineStatus = "Next track will load normally"
      } else {
        preloadDetail = shouldPreloadNextTrack ? "End of queue" : "Preloading disabled"
        playbackEngineStatus = shouldPreloadNextTrack ? "Playing — end of queue" : "Gapless preload off"
      }
      elapsed = min(max(0, startTime), max(0, duration - 0.05))
      playbackAnchorElapsed = elapsed
      playbackAnchorDate = autoPlay ? Date() : nil
      isPlaying = autoPlay
      if !autoPlay { gaplessEngine.pause() }
      if notifyTrackStarted {
        ResonanceDiagnostics.shared.record("playback.trackStarted.callback.begin")
        onTrackStarted?(track)
        ResonanceDiagnostics.shared.record("playback.trackStarted.callback.end")
      }
      lastNowPlayingProgressUpdate = 0
      hasRecordedFirstPlaybackTick = false
      markPlaybackRuntimeStage("Publishing Lock Screen metadata")
      updateNowPlaying()
      markPlaybackRuntimeStage("Lock Screen metadata published; scheduling playback timer")
      startPlaybackTimer()
      markPlaybackRuntimeStage("Playback timer scheduled")
      markPlaybackStartupStage("Local playback started successfully")
      return true
    } catch {
      let isMatrixFailure: Bool
      if let engineError = error as? GaplessAudioEngine.EngineError,
         case .matrixConfigurationFailed = engineError {
        isMatrixFailure = true
      } else {
        isMatrixFailure = false
      }

      // Never reuse or reset an AVAudioEngine whose graph failed midway
      // through Matrix Mixer configuration. Quarantine it for this process and
      // route local playback through the stable compatibility player.
      if isMatrixFailure {
        quarantineGaplessEngineAfterMatrixFailure()
      } else {
        gaplessEngine.stop(resetEngine: true)
      }
      let failureStage = isMatrixFailure
        ? "Surround matrix failed; opening compatibility player"
        : "Local engine failed; opening compatibility player"
      markPlaybackStartupStage(failureStage)
      reportRuntimeError("Local gapless engine failed: \(error.localizedDescription)")
      playbackEngineStatus = isMatrixFailure
        ? "Compatibility fallback — gapless disabled until relaunch"
        : "Compatibility fallback"
      return loadWithLegacyPlayer(
        track,
        url: url,
        at: resolvedIndex,
        startTime: startTime,
        autoPlay: autoPlay,
        notifyTrackStarted: notifyTrackStarted,
        successfulStartupStage: isMatrixFailure
          ? "Compatibility playback started successfully after matrix failure"
          : "Compatibility playback started successfully"
      )
    }
  }

  private func loadWithLegacyPlayer(
    _ track: Track,
    url: URL,
    at targetIndex: Int,
    startTime: TimeInterval,
    autoPlay: Bool,
    notifyTrackStarted: Bool,
    successfulStartupStage: String = "Compatibility playback started successfully"
  ) -> Bool {
    do {
      let newPlayer = try AVAudioPlayer(contentsOf: url)
      newPlayer.delegate = audioDelegate
      newPlayer.isMeteringEnabled = true
      newPlayer.volume = Float(min(max(volume, 0), 1))
      newPlayer.prepareToPlay()
      newPlayer.currentTime = safeSeekPosition(startTime, duration: newPlayer.duration)
      if autoPlay, !newPlayer.play() {
        markPlaybackStartupStage("Compatibility player refused to start")
        reportRuntimeError("Compatibility playback could not start the selected local file.")
        clearUnplayableTrack()
        return false
      }
      audioPlayer = newPlayer
      activeBackend = .legacy
      preloadDetail = "Compatibility player does not use rolling preload"
      audioFormatStatus = "System-managed audio output"
      downmixRoutingStatus = "System-managed compatibility routing"
      currentQueueIndex = targetIndex
      currentTrack = track
      duration = newPlayer.duration
      elapsed = newPlayer.currentTime
      playbackAnchorElapsed = elapsed
      playbackAnchorDate = autoPlay ? Date() : nil
      isPlaying = autoPlay
      if notifyTrackStarted {
        ResonanceDiagnostics.shared.record("playback.trackStarted.callback.begin")
        onTrackStarted?(track)
        ResonanceDiagnostics.shared.record("playback.trackStarted.callback.end")
      }
      lastNowPlayingProgressUpdate = 0
      hasRecordedFirstPlaybackTick = false
      markPlaybackRuntimeStage("Publishing Lock Screen metadata")
      updateNowPlaying()
      markPlaybackRuntimeStage("Lock Screen metadata published; scheduling playback timer")
      startPlaybackTimer()
      markPlaybackRuntimeStage("Playback timer scheduled")
      markPlaybackStartupStage(successfulStartupStage)
      return true
    } catch {
      markPlaybackStartupStage("Compatibility playback failed")
      reportRuntimeError("Compatibility playback failed: \(error.localizedDescription)")
      clearUnplayableTrack()
      return false
    }
  }

  private func loadWithRemotePlayer(
    _ track: Track,
    url: URL,
    at targetIndex: Int,
    startTime: TimeInterval,
    autoPlay: Bool,
    notifyTrackStarted: Bool
  ) -> Bool {
    let item = makeRemoteItem(for: track, url: url)
    let experimentalGapless = remoteGaplessExperimentalEnabled
    let nextTrack = experimentalGapless ? remotePreloadCandidate(after: targetIndex) : nil
    let newPlayer = AVPlayer(playerItem: item)
    remotePlayer = newPlayer
    remoteExperimentalSession = experimentalGapless
    // A queued remote item must be allowed to start as soon as its available
    // media begins. Experimental handoff uses a separately prerolling player;
    // the stable single-item path retains AVPlayer's normal stall protection.
    newPlayer.automaticallyWaitsToMinimizeStalling = !experimentalGapless
    newPlayer.volume = Float(min(max(volume, 0), 1))
    remoteItemTracks = [ObjectIdentifier(item): track]
    remoteObserver.observe(item)
    activeBackend = .remote
    currentQueueIndex = targetIndex
    currentTrack = track
    duration = max(0, track.duration)
    elapsed = safeSeekPosition(startTime, duration: duration)
    playbackAnchorElapsed = elapsed
    playbackAnchorDate = autoPlay ? Date() : nil
    isPlaying = autoPlay
    preloadedTrackID = nil
    preloadedTrackTitle = nil
    remoteSeekInFlight = false
    remoteSeekRequestID &+= 1
    pendingRemoteSeekPosition = nil
    remoteEndHandledTrackID = nil
    if experimentalGapless, let nextTrack {
      preloadedTrackID = nextTrack.id
      preloadedTrackTitle = nextTrack.title
      preloadDetail = "Experimental remote gapless candidate queued"
    } else if experimentalGapless {
      preloadDetail = "Experimental remote gapless — end of queue"
    } else {
      preloadDetail = "Stable single-item remote playback"
    }
    audioFormatStatus = "Remote stream — system audio output"
    downmixRoutingStatus = "Remote stream uses system channel routing"
    networkBufferStatus = "Connecting to remote stream…"
    playbackEngineStatus = experimentalGapless
      ? "Remote gapless — connecting"
      : "Remote streaming — connecting"
    ResonanceDiagnostics.shared.record(
      "remote.player.queueConfigured",
      details: [
        "experimental": String(experimentalGapless),
        "queuedNext": String(nextTrack != nil)
      ]
    )

    if let nextTrack {
      beginRemotePreload(nextTrack, generation: playbackGeneration)
    }

    if elapsed > 0 {
      newPlayer.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600))
    }
    if autoPlay {
      ResonanceDiagnostics.shared.record("remote.player.play.begin")
      if experimentalGapless {
        newPlayer.playImmediately(atRate: 1)
      } else {
        newPlayer.play()
      }
      ResonanceDiagnostics.shared.record("remote.player.play.end")
    }
    if notifyTrackStarted {
      ResonanceDiagnostics.shared.record("playback.trackStarted.callback.begin")
      onTrackStarted?(track)
      ResonanceDiagnostics.shared.record("playback.trackStarted.callback.end")
    }
    lastNowPlayingProgressUpdate = 0
    hasRecordedFirstPlaybackTick = false
    markPlaybackRuntimeStage("Publishing Lock Screen metadata")
    updateNowPlaying()
    markPlaybackRuntimeStage("Lock Screen metadata published; scheduling playback timer")
    startPlaybackTimer()
    markPlaybackRuntimeStage("Playback timer scheduled")
    markPlaybackStartupStage("Remote playback started successfully")
    return true
  }

  private func makeRemoteItem(for track: Track, url: URL) -> AVPlayerItem {
    let item = AVPlayerItem(url: url)
    item.preferredForwardBufferDuration = remoteForwardBufferDuration(for: track)
    item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
    return item
  }

  private func clearRemotePreload() {
    remotePreloadTask?.cancel()
    remotePreloadTask = nil
    remotePreloadPlayer?.cancelPendingPrerolls()
    remotePreloadPlayer?.pause()
    remotePreloadPlayer?.replaceCurrentItem(with: nil)
    remotePreloadPlayer = nil
    remotePreloadItem = nil
    remotePreloadTrack = nil
    remotePreloadReady = false
  }

  /// A queued AVPlayer item can be present before its decoder has been
  /// primed. Keep the next item on a separate silent player and explicitly
  /// preroll it so the boundary handoff can reuse a warmed decoder instead of
  /// starting a cold network item at the exact end of the previous one.
  private func beginRemotePreload(_ track: Track, generation: Int) {
    clearRemotePreload()
    guard remoteExperimentalSession,
      let url = track.fileURL,
      url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
    else {
      preloadedTrackID = nil
      preloadedTrackTitle = nil
      return
    }

    let item = makeRemoteItem(for: track, url: url)
    let player = AVPlayer(playerItem: item)
    player.automaticallyWaitsToMinimizeStalling = false
    player.volume = 0
    remotePreloadPlayer = player
    remotePreloadItem = item
    remotePreloadTrack = track
    remotePreloadReady = false
    remoteItemTracks[ObjectIdentifier(item)] = track
    preloadedTrackID = track.id
    preloadedTrackTitle = track.title
    preloadDetail = "Experimental remote gapless candidate preloading"

    remotePreloadTask = Task { @MainActor [weak self] in
      for _ in 0..<300 {
        guard !Task.isCancelled,
          let self,
          self.playbackGeneration == generation,
          self.remoteExperimentalSession,
          let preloadPlayer = self.remotePreloadPlayer,
          preloadPlayer === player,
          let preloadItem = self.remotePreloadItem,
          preloadItem === item
        else { return }

        switch preloadItem.status {
        case .readyToPlay:
          preloadPlayer.preroll(atRate: 1) { [weak self, weak preloadPlayer] finished in
            Task { @MainActor [weak self, weak preloadPlayer] in
              guard let self,
                let preloadPlayer,
                self.playbackGeneration == generation,
                self.remotePreloadPlayer === preloadPlayer
              else { return }
              self.remotePreloadReady = finished
              self.preloadDetail = finished
                ? "Experimental remote gapless candidate ready"
                : "Experimental remote gapless candidate buffering"
              ResonanceDiagnostics.shared.recordDeferred(
                "remote.player.preload.ready",
                details: [
                  "finished": String(finished),
                  "likelyToKeepUp": String(preloadItem.isPlaybackLikelyToKeepUp),
                  "loadedSeconds": String(format: "%.3f", self.loadedSeconds(for: preloadItem))
                ]
              )
            }
          }
          return
        case .failed:
          self.preloadDetail = "Experimental remote gapless preload failed"
          ResonanceDiagnostics.shared.recordDeferred(
            "remote.player.preload.failed",
            details: ["reason": preloadItem.error?.localizedDescription ?? "unknown"]
          )
          return
        case .unknown:
          break
        @unknown default:
          break
        }
        try? await Task.sleep(for: .milliseconds(100))
      }

      guard !Task.isCancelled,
        let self,
        self.playbackGeneration == generation,
        self.remoteExperimentalSession,
        self.remotePreloadPlayer === player
      else { return }
      self.preloadDetail = "Experimental remote gapless preload timed out"
      ResonanceDiagnostics.shared.recordDeferred("remote.player.preload.timeout")
    }
  }

  private func loadedSeconds(for item: AVPlayerItem) -> Double {
    item.loadedTimeRanges.compactMap { value in
      let range = value.timeRangeValue
      let end = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
      return end.isFinite ? end : nil
    }.max() ?? 0
  }

  private func scheduleRemoteGaplessHandoffIfNeeded() {
    guard remoteExperimentalSession,
      remoteGaplessExperimentalEnabled,
      remoteGaplessHandoffTask == nil,
      let currentTrack,
      let oldPlayer = remotePlayer,
      oldPlayer.currentItem != nil,
      duration.isFinite,
      duration > 0,
      elapsed >= max(0, duration - remoteGaplessHandoffDuration),
      remoteEndHandledTrackID != currentTrack.id,
      let targetIndex = nextQueueIndex(after: currentQueueIndex),
      queue.indices.contains(targetIndex)
    else { return }

    let target = queue[targetIndex]
    guard remotePreloadTrack?.id == target.id,
      remotePreloadReady,
      let targetPlayer = remotePreloadPlayer,
      let targetItem = remotePreloadItem
    else { return }

    let generation = playbackGeneration
    let finishedTrackID = currentTrack.id
    let oldVolume = Float(min(max(volume, 0), 1))
    remoteEndHandledTrackID = finishedTrackID
    targetPlayer.volume = 0
    targetPlayer.playImmediately(atRate: 1)
    ResonanceDiagnostics.shared.recordDeferred(
      "remote.player.boundary.begin",
      details: [
        "generation": String(generation),
        "queueIndex": String(targetIndex),
        "preloadedTarget": "true",
        "preloadReady": "true",
        "handoffDuration": String(format: "%.3f", remoteGaplessHandoffDuration)
      ]
    )

    remoteGaplessHandoffTask = Task { @MainActor [weak self] in
      let steps = 7
      for step in 1...steps {
        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled,
          let self,
          self.playbackGeneration == generation,
          self.remoteGaplessHandoffTask != nil,
          self.remotePlayer === oldPlayer,
          self.remotePreloadPlayer === targetPlayer,
          self.remotePreloadItem === targetItem,
          self.currentTrack?.id == finishedTrackID
        else {
          self?.remoteGaplessHandoffTask = nil
          return
        }

        let fraction = Float(step) / Float(steps)
        oldPlayer.volume = oldVolume * (1 - fraction)
        targetPlayer.volume = oldVolume * fraction
      }

      self?.commitRemoteGaplessHandoff(
        finishedTrackID: finishedTrackID,
        target: target,
        targetIndex: targetIndex,
        oldPlayer: oldPlayer,
        targetPlayer: targetPlayer,
        targetItem: targetItem,
        generation: generation
      )
    }
  }

  private func commitRemoteGaplessHandoff(
    finishedTrackID: UUID,
    target: Track,
    targetIndex: Int,
    oldPlayer: AVPlayer,
    targetPlayer: AVPlayer,
    targetItem: AVPlayerItem,
    generation: Int
  ) {
    guard playbackGeneration == generation,
      activeBackend == .remote,
      remotePlayer === oldPlayer,
      remotePreloadPlayer === targetPlayer,
      remotePreloadItem === targetItem,
      currentTrack?.id == finishedTrackID
    else {
      remoteGaplessHandoffTask = nil
      return
    }

    remoteGaplessHandoffTask = nil
    remotePreloadTask?.cancel()
    remotePreloadTask = nil
    remotePlayer = targetPlayer
    remotePreloadPlayer = nil
    remotePreloadItem = nil
    remotePreloadTrack = nil
    remotePreloadReady = false
    remoteObserver.observe(targetItem)
    oldPlayer.pause()
    oldPlayer.cancelPendingPrerolls()
    oldPlayer.replaceCurrentItem(with: nil)
    targetPlayer.volume = Float(min(max(volume, 0), 1))

    currentQueueIndex = targetIndex
    currentTrack = target
    duration = max(0, target.duration)
    let targetElapsed = targetPlayer.currentTime().seconds
    elapsed = targetElapsed.isFinite ? clampedRemoteElapsed(targetElapsed) : 0
    playbackAnchorElapsed = elapsed
    playbackAnchorDate = Date()
    clearRemoteClockHold()
    isPlaying = true
    remoteEndHandledTrackID = finishedTrackID
    networkBufferStatus = "Connecting to remote stream…"
    playbackEngineStatus = "Remote gapless — ready"
    onTrackStarted?(target)
    refreshRemotePreloadAfterQueueChange()
    updateNowPlaying()
    ResonanceDiagnostics.shared.recordDeferred(
      "remote.player.boundary.end",
      details: [
        "result": "advanced",
        "queueIndex": String(targetIndex),
        "preloadedTarget": "true",
        "preloadReady": "true",
        "handoff": "overlap"
      ]
    )
  }

  fileprivate func handleRemotePlaybackFinished(_ item: AVPlayerItem) {
    guard activeBackend == .remote,
      let finishedTrack = remoteItemTracks[ObjectIdentifier(item)]
    else { return }
    guard remoteEndHandledTrackID != finishedTrack.id else { return }
    if remoteExperimentalSession, currentTrack?.id == finishedTrack.id {
      scheduleRemoteGaplessHandoffIfNeeded()
      if remoteGaplessHandoffTask != nil { return }
    }
    remoteEndHandledTrackID = finishedTrack.id
    ResonanceDiagnostics.shared.record(
      "remote.player.finished",
      details: [
        "generation": String(playbackGeneration),
        "experimental": String(remoteExperimentalSession)
      ]
    )
    if sleepTimerOption == .endOfTrack {
      stop()
    } else if remoteExperimentalSession {
      handleRemoteQueueBoundary(finishedTrack)
    } else if repeatMode == .one, let currentTrack {
      _ = loadAndPlay(currentTrack, at: currentQueueIndex)
    } else {
      next()
    }
  }

  private func handleRemoteQueueBoundary(_ finishedTrack: Track) {
    let finishedIndex = queue.firstIndex(of: finishedTrack) ?? currentQueueIndex

    if repeatMode == .one {
      guard let currentItem = activeRemotePlayer?.currentItem else {
        _ = loadAndPlay(finishedTrack, at: finishedIndex)
        return
      }
      currentItem.seek(
        to: .zero,
        toleranceBefore: .zero,
        toleranceAfter: .zero,
        completionHandler: nil
      )
      currentQueueIndex = finishedIndex
      currentTrack = finishedTrack
      elapsed = 0
      playbackAnchorElapsed = 0
      playbackAnchorDate = Date()
      clearRemoteClockHold()
      isPlaying = true
      remoteEndHandledTrackID = nil
      activeRemotePlayer?.playImmediately(atRate: 1)
      onTrackStarted?(finishedTrack)
      updateNowPlaying()
      ResonanceDiagnostics.shared.recordDeferred(
        "remote.player.boundary.end",
        details: ["result": "repeated"]
      )
      return
    }

    guard let targetIndex = nextQueueIndex(after: finishedIndex),
      queue.indices.contains(targetIndex)
    else {
      stop()
      ResonanceDiagnostics.shared.recordDeferred(
        "remote.player.boundary.end",
        details: ["result": "stopped-at-end"]
      )
      return
    }

    let target = queue[targetIndex]
    let targetIsPreloaded = remotePreloadTrack?.id == target.id
    let targetPreloadReady = targetIsPreloaded && remotePreloadReady
    guard targetIsPreloaded,
      let targetPlayer = remotePreloadPlayer,
      let targetItem = remotePreloadItem
    else {
      ResonanceDiagnostics.shared.recordDeferred(
        "remote.player.boundary.end",
        details: [
          "result": "fallback-load",
          "preloadedTarget": String(targetIsPreloaded),
          "preloadReady": String(targetPreloadReady)
        ]
      )
      _ = loadAndPlay(target, at: targetIndex)
      return
    }

    remoteGaplessHandoffTask?.cancel()
    remoteGaplessHandoffTask = nil
    let oldPlayer = remotePlayer
    remotePreloadTask?.cancel()
    remotePreloadTask = nil
    remotePlayer = targetPlayer
    remotePreloadPlayer = nil
    remotePreloadItem = nil
    remotePreloadTrack = nil
    remotePreloadReady = false
    remoteObserver.observe(targetItem)
    oldPlayer?.pause()
    oldPlayer?.cancelPendingPrerolls()
    oldPlayer?.replaceCurrentItem(with: nil)
    targetPlayer.volume = Float(min(max(volume, 0), 1))

    currentQueueIndex = targetIndex
    currentTrack = target
    duration = max(0, target.duration)
    elapsed = 0
    playbackAnchorElapsed = 0
    playbackAnchorDate = Date()
    clearRemoteClockHold()
    isPlaying = true
    remoteEndHandledTrackID = finishedTrack.id
    networkBufferStatus = "Connecting to remote stream…"
    playbackEngineStatus = targetPreloadReady
      ? "Remote gapless — ready"
      : "Remote gapless — buffering"
    // Start the newly current item before callbacks and queue maintenance can
    // do additional main-actor work at the boundary.
    targetPlayer.playImmediately(atRate: 1)
    onTrackStarted?(target)
    refreshRemotePreloadAfterQueueChange()
    updateNowPlaying()
    ResonanceDiagnostics.shared.recordDeferred(
      "remote.player.boundary.end",
      details: [
        "result": "advanced",
        "queueIndex": String(targetIndex),
        "preloadedTarget": String(targetIsPreloaded),
        "preloadReady": String(targetPreloadReady)
      ]
    )
  }

  private func refreshRemotePreloadAfterQueueChange() {
    guard remoteExperimentalSession,
      remoteGaplessExperimentalEnabled,
      remotePlayer?.currentItem != nil,
      currentTrack != nil
    else { return }

    let expected = remotePreloadCandidate(after: currentQueueIndex)
    if expected?.id == preloadedTrackID,
      remotePreloadTrack?.id == expected?.id
    {
      return
    }

    clearRemotePreload()
    preloadedTrackID = nil
    preloadedTrackTitle = nil

    guard let expected, let url = expected.fileURL else {
      preloadDetail = "Experimental remote gapless — end of queue"
      return
    }

    guard url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
      preloadDetail = "Experimental remote gapless — invalid next URL"
      return
    }
    beginRemotePreload(expected, generation: playbackGeneration)
  }

  private func remoteForwardBufferDuration(for track: Track) -> TimeInterval {
    let budgetBytes = max(10, networkBufferMegabytes) * 1_048_576
    if track.sourceByteSize > 0, track.duration > 0 {
      let bytesPerSecond = Double(track.sourceByteSize) / track.duration
      if bytesPerSecond > 0 {
        return min(max(8, Double(budgetBytes) / bytesPerSecond), max(8, track.duration))
      }
    }
    return min(max(15, Double(networkBufferMegabytes) * 0.75), 300)
  }

  private var networkBufferMegabytes: Int {
    let configured = UserDefaults.standard.double(forKey: "networkBufferMB")
    return Int(configured > 0 ? configured : 128)
  }

  private func updateRemoteBufferStatus() {
    guard activeBackend == .remote,
      let activeRemotePlayer,
      let item = activeRemotePlayer.currentItem
    else { return }
    let itemDuration = item.duration.seconds
    if itemDuration.isFinite, itemDuration > 0, abs(duration - itemDuration) > 0.01 {
      duration = itemDuration
      elapsed = clampedRemoteElapsed(elapsed)
      playbackAnchorElapsed = clampedRemoteElapsed(playbackAnchorElapsed)
    }

    let loadedEnd: Double = item.loadedTimeRanges.compactMap { value in
      let range = value.timeRangeValue
      let end = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
      return end.isFinite ? end : nil
    }.max() ?? elapsed
    let ahead = max(0, loadedEnd - elapsed)

    let approximateMegabytes: Double? = {
      guard let track = currentTrack, track.sourceByteSize > 0, duration > 0 else { return nil }
      return min(Double(track.sourceByteSize), (ahead / duration) * Double(track.sourceByteSize)) / 1_048_576
    }()

    let now = Date()
    let shouldPublishBufferText = now.timeIntervalSince(lastRemoteBufferStatusPublicationDate) >= 0.5

    switch item.status {
    case .failed:
      if playbackEngineStatus != "Remote stream failed" {
        playbackEngineStatus = "Remote stream failed"
      }
      let failureStatus = item.error?.localizedDescription ?? "The remote player reported an error"
      if networkBufferStatus != failureStatus {
        networkBufferStatus = failureStatus
      }
      lastRemoteBufferStatusPublicationDate = now
      reportRuntimeError("Remote playback failed: \(networkBufferStatus)")
      isPlaying = false
    case .readyToPlay:
      let playbackStatus: String
      switch activeRemotePlayer.timeControlStatus {
      case .waitingToPlayAtSpecifiedRate:
        playbackStatus = "Remote streaming — buffering"
      case .playing:
        playbackStatus = "Remote streaming"
      case .paused:
        playbackStatus = isPlaying ? "Remote stream paused while buffering" : "Remote stream paused"
      @unknown default:
        playbackStatus = "Remote streaming"
      }
      if playbackEngineStatus != playbackStatus {
        playbackEngineStatus = playbackStatus
      }
      if shouldPublishBufferText {
        if let approximateMegabytes {
          networkBufferStatus = String(format: "%.1f MB buffered • %.0f seconds ahead", approximateMegabytes, ahead)
        } else {
          networkBufferStatus = String(format: "%.0f seconds buffered ahead", ahead)
        }
        lastRemoteBufferStatusPublicationDate = now
      }
    case .unknown:
      if playbackEngineStatus != "Remote streaming — connecting" {
        playbackEngineStatus = "Remote streaming — connecting"
      }
      if shouldPublishBufferText {
        networkBufferStatus = "Waiting for the server response…"
        lastRemoteBufferStatusPublicationDate = now
      }
    @unknown default:
      break
    }

    if item.status == .readyToPlay,
      isPlaying,
      !remoteSeekInFlight,
      remoteGaplessHandoffTask == nil,
      activeRemotePlayer.timeControlStatus == .paused,
      duration > 0,
      elapsed >= max(0, duration - 0.35)
    {
      ResonanceDiagnostics.shared.record(
        "remote.player.endFallback",
        details: [
          "elapsed": String(format: "%.3f", elapsed),
          "duration": String(format: "%.3f", duration)
        ]
      )
      handleRemotePlaybackFinished(item)
    }
  }

  private static func loadBookmarks() -> [PlaybackBookmark] {
    guard let data = UserDefaults.standard.data(forKey: "resonance.playbackBookmarks"),
      let decoded = try? JSONDecoder().decode([PlaybackBookmark].self, from: data)
    else {
      return []
    }
    return decoded
  }

  private func persistBookmarks() {
    if let data = try? JSONEncoder().encode(bookmarks) {
      UserDefaults.standard.set(data, forKey: "resonance.playbackBookmarks")
    }
  }

  private func uniqueTracks(_ tracks: [Track]) -> [Track] {
    var seen = Set<UUID>()
    return tracks.filter { seen.insert($0.id).inserted }
  }

  private func artworkSource(for track: Track) -> Track? {
    let candidates = queue + sourceQueue
    return candidates.first {
      $0.artworkData != nil && $0.album.caseInsensitiveCompare(track.album) == .orderedSame
        && $0.albumArtist.caseInsensitiveCompare(track.albumArtist) == .orderedSame
    }
  }

  private var shouldPreloadNextTrack: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "preloadNextTrack") == nil { return true }
    return defaults.bool(forKey: "preloadNextTrack")
  }

  private var localPreloadBudgetBytes: Int64 {
    let configured = UserDefaults.standard.double(forKey: "localBufferMB")
    let megabytes = configured > 0 ? configured : 64
    return Int64(megabytes * 1_048_576)
  }

  private func nextQueueIndex(after index: Int) -> Int? {
    let next = index + 1
    if queue.indices.contains(next) { return next }
    if repeatMode == .all, !queue.isEmpty { return 0 }
    return nil
  }

  private func preloadQueueIndex(after index: Int) -> Int? {
    if repeatMode == .one, queue.indices.contains(index) { return index }
    return nextQueueIndex(after: index)
  }

  private func preloadCandidate(after index: Int) -> Track? {
    guard shouldPreloadNextTrack,
      let candidateIndex = preloadQueueIndex(after: index),
      queue.indices.contains(candidateIndex)
    else { return nil }
    let candidate = queue[candidateIndex]
    guard let url = candidate.fileURL, FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }
    return candidate
  }

  private func remotePreloadCandidate(after index: Int) -> Track? {
    guard remoteGaplessExperimentalEnabled,
      shouldPreloadNextTrack,
      let candidateIndex = preloadQueueIndex(after: index),
      queue.indices.contains(candidateIndex)
    else { return nil }
    let candidate = queue[candidateIndex]
    guard let url = candidate.fileURL,
      url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https"
    else { return nil }
    return candidate
  }

  private static func audioFormatDescription(
    sourceChannels: AVAudioChannelCount,
    outputChannels: AVAudioChannelCount
  ) -> String {
    if sourceChannels > outputChannels {
      return "\(sourceChannels)-channel source → stereo downmix"
    }
    if sourceChannels == 1 { return "Mono source → stereo output" }
    return "Stereo output"
  }

  private func safeSeekPosition(_ requested: Double, duration: Double) -> Double {
    guard duration.isFinite, duration > 0 else { return 0 }
    // A user seek must be allowed to reach the real endpoint. Natural remote
    // completion is separately guarded by remoteSeekInFlight and the end
    // fallback, so an artificial endpoint offset only makes the scrubber lie.
    return min(max(0, requested), duration)
  }

  private func clampedRemoteElapsed(_ requested: Double) -> Double {
    guard requested.isFinite else { return max(0, elapsed) }
    guard duration.isFinite, duration > 0 else { return max(0, requested) }
    return min(max(0, requested), duration)
  }

  private func clearRemoteClockHold() {
    remoteClockHoldPosition = nil
    remoteClockHoldStartedAt = nil
    remoteClockHoldWasPlaying = false
  }

  private func updateElapsedFromClock() {
    switch activeBackend {
    case .gapless:
      guard isPlaying, let playbackAnchorDate else { return }
      elapsed = min(duration, playbackAnchorElapsed + Date().timeIntervalSince(playbackAnchorDate))
    case .legacy:
      if let audioPlayer { elapsed = audioPlayer.currentTime }
    case .remote:
      if let holdPosition = remoteClockHoldPosition,
        let holdStartedAt = remoteClockHoldStartedAt
      {
        let holdAge = Date().timeIntervalSince(holdStartedAt)
        if holdAge < remoteClockHoldDuration {
          let heldElapsed = remoteClockHoldWasPlaying
            ? holdPosition + max(0, holdAge)
            : holdPosition
          elapsed = clampedRemoteElapsed(heldElapsed)
          return
        }
        clearRemoteClockHold()
      }
      if let activeRemotePlayer, !remoteSeekInFlight {
        let seconds = activeRemotePlayer.currentTime().seconds
        if seconds.isFinite { elapsed = clampedRemoteElapsed(seconds) }
      }
    case .none:
      break
    }
  }

  private func refreshPreloadedTrackAfterQueueChange() {
    switch activeBackend {
    case .remote:
      refreshRemotePreloadAfterQueueChange()
    case .gapless:
      guard let currentTrack else { return }
      let expected = preloadCandidate(after: currentQueueIndex)?.id
      guard expected != preloadedTrackID else { return }
      updateElapsedFromClock()
      let wasPlaying = isPlaying
      _ = loadAndPlay(
        currentTrack,
        at: currentQueueIndex,
        startTime: elapsed,
        autoPlay: wasPlaying,
        notifyTrackStarted: false
      )
    case .legacy, .none:
      break
    }
  }

  private func handleGaplessTrackFinished(trackID: UUID, generation: Int) {
    guard generation == playbackGeneration,
      activeBackend == .gapless,
      currentTrack?.id == trackID
    else { return }

    if sleepTimerOption == .endOfTrack {
      stop()
      return
    }

    let targetIndex: Int?
    if repeatMode == .one {
      targetIndex = currentQueueIndex
    } else {
      targetIndex = nextQueueIndex(after: currentQueueIndex)
    }

    let hasPreloadedTarget = targetIndex.flatMap { index in
      queue.indices.contains(index) ? queue[index].id == preloadedTrackID : nil
    } ?? false
    ResonanceDiagnostics.shared.record(
      "playback.gapless.boundary.begin",
      details: [
        "queueIndex": String(currentQueueIndex),
        "targetAvailable": String(targetIndex != nil),
        "preloadedTarget": String(hasPreloadedTarget),
        "repeatMode": repeatMode.rawValue
      ]
    )

    guard let targetIndex, queue.indices.contains(targetIndex) else {
      stop()
      ResonanceDiagnostics.shared.record(
        "playback.gapless.boundary.end",
        details: ["result": "stopped-at-end"]
      )
      return
    }

    let target = queue[targetIndex]
    guard preloadedTrackID == target.id else {
      ResonanceDiagnostics.shared.record(
        "playback.gapless.boundary.end",
        details: ["result": "fallback-load"]
      )
      _ = loadAndPlay(target, at: targetIndex)
      return
    }

    currentQueueIndex = targetIndex
    currentTrack = target
    duration = engineDurations[target.id] ?? max(0, target.duration)
    if let channels = engineChannelCounts[target.id] {
      audioFormatStatus = Self.audioFormatDescription(
        sourceChannels: channels,
        outputChannels: gaplessEngine.outputChannelCount
      )
      downmixRoutingStatus = gaplessEngine.downmixRoutingDescription
    }
    elapsed = 0
    playbackAnchorElapsed = 0
    playbackAnchorDate = isPlaying ? Date() : nil
    lastNowPlayingProgressUpdate = 0
    preloadedTrackID = nil
    preloadedTrackTitle = nil

    if let remainingStartFrame = partialPreloadFrames.removeValue(forKey: target.id),
      let targetURL = target.fileURL
    {
      do {
        _ = try gaplessEngine.appendRemainder(
          trackID: target.id,
          url: targetURL,
          startingFrame: remainingStartFrame,
          generation: playbackGeneration
        )
        preloadDetail = "Large track is streaming after its preloaded opening segment"
      } catch {
        playbackEngineStatus = "Partial preload continuation failed"
      }
    }

    onTrackStarted?(target)
    scheduleTrackAfterCurrentBoundary()
    updateNowPlaying()
    ResonanceDiagnostics.shared.record(
      "playback.gapless.boundary.end",
      details: ["result": "advanced"]
    )
  }

  private func scheduleTrackAfterCurrentBoundary() {
    guard activeBackend == .gapless,
      let candidate = preloadCandidate(after: currentQueueIndex),
      let url = candidate.fileURL
    else {
      preloadedTrackID = nil
      preloadedTrackTitle = nil
      preloadDetail = shouldPreloadNextTrack ? "End of queue" : "Preloading disabled"
      playbackEngineStatus = shouldPreloadNextTrack ? "Playing — end of queue" : "Gapless preload off"
      return
    }

    do {
      let scheduled = try gaplessEngine.appendPreloaded(
        trackID: candidate.id,
        url: url,
        preloadBudgetBytes: localPreloadBudgetBytes,
        generation: playbackGeneration
      )
      engineDurations[candidate.id] = scheduled.duration
      engineChannelCounts[candidate.id] = scheduled.channelCount
      preloadedTrackID = candidate.id
      preloadedTrackTitle = candidate.title
      if let remainingFrame = scheduled.remainingStartFrame {
        partialPreloadFrames[candidate.id] = remainingFrame
        preloadDetail = "Opening segment scheduled; remainder streams from disk"
        playbackEngineStatus = "Gapless ready — partial preload"
        ResonanceDiagnostics.shared.record(
          "playback.gapless.preload",
          details: ["result": "partial"]
        )
      } else {
        partialPreloadFrames[candidate.id] = nil
        preloadDetail = "Complete next track scheduled"
        playbackEngineStatus = "Gapless ready"
        ResonanceDiagnostics.shared.record(
          "playback.gapless.preload",
          details: ["result": "complete"]
        )
      }
    } catch {
      preloadedTrackID = nil
      preloadedTrackTitle = nil
      preloadDetail = "The next file could not be opened by the gapless engine"
      playbackEngineStatus = "Next track will load normally"
      ResonanceDiagnostics.shared.record(
        "playback.gapless.preload",
        details: ["result": "failed"]
      )
    }
  }

  private func clearUnplayableTrack() {
    if !playbackStartupDiagnostic.contains("failed") {
      markPlaybackStartupStage("Playback request rejected as unplayable")
    }
    playbackGeneration += 1
    playbackTimerTask?.cancel()
    playbackTimerTask = nil
    tearDownActiveBackend()
    activeBackend = .none
    currentTrack = nil
    isPlaying = false
    elapsed = 0
    duration = 0
    meterLevel = 0
    playbackAnchorDate = nil
    playbackAnchorElapsed = 0
    preloadedTrackID = nil
    preloadedTrackTitle = nil
    preloadDetail = "No track preloaded"
    audioFormatStatus = "Stereo output ready"
    downmixRoutingStatus = "Automatic stereo routing"
    engineDurations.removeAll()
    engineChannelCounts.removeAll()
    partialPreloadFrames.removeAll()
    networkBufferStatus = "No remote stream active"
    playbackEngineStatus = "Unable to play this file"
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  private func startPlaybackTimer() {
    playbackTimerTask?.cancel()
    playbackTimerTickCount = 0
    ResonanceDiagnostics.shared.recordDeferred("playback.timer.created")
    playbackTimerTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled, let self else { return }
        self.updatePlaybackClockAndMeters()
      }
    }
  }

  private func updatePlaybackClockAndMeters() {
    playbackTimerTickCount += 1
    let shouldLogTick = playbackTimerTickCount <= 3
    if shouldLogTick {
      ResonanceDiagnostics.shared.recordDeferred(
        "playback.timer.tick.begin",
        details: ["tick": String(playbackTimerTickCount)]
      )
    }
    updateElapsedFromClock()

    switch activeBackend {
    case .gapless:
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.gapless.begin") }
      meterLevel = isPlaying ? gaplessEngine.meterLevel : 0.08
      if shouldLogTick {
        ResonanceDiagnostics.shared.recordDeferred(
          "playback.timer.gapless.end",
          details: [
            "meter": String(format: "%.5f", gaplessEngine.meterLevel),
            "engineRunning": String(gaplessEngine.isEngineRunning),
            "playerNodePlaying": String(gaplessEngine.isPlaying)
          ]
        )
      }
    case .legacy:
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.legacy.begin") }
      if let audioPlayer {
        audioPlayer.updateMeters()
        let decibels = audioPlayer.averagePower(forChannel: 0)
        let linear = pow(10.0, Double(decibels) / 20.0)
        meterLevel = audioPlayer.isPlaying ? min(1, max(0.06, linear * 4.5)) : 0.08
      }
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.legacy.end") }
    case .remote:
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.remoteBuffer.begin") }
      scheduleRemoteGaplessHandoffIfNeeded()
      updateRemoteBufferStatus()
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.remoteBuffer.end") }
      meterLevel = isPlaying ? 0.24 + (sin(elapsed * 3.7) + 1) * 0.12 : 0.08
    case .none:
      meterLevel = 0
    }

    if !hasRecordedFirstPlaybackTick {
      hasRecordedFirstPlaybackTick = true
      markPlaybackRuntimeStage("First playback timer tick completed")
    }

    if abs(elapsed - lastNowPlayingProgressUpdate) >= 0.8 {
      lastNowPlayingProgressUpdate = elapsed
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.nowPlayingProgress.begin") }
      updateNowPlayingProgress()
      if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.nowPlayingProgress.end") }
    }
    if shouldLogTick { ResonanceDiagnostics.shared.recordDeferred("playback.timer.tick.end") }
  }

  fileprivate func handlePlaybackFinished(_ finishedPlayer: AVAudioPlayer, successfully: Bool) {
    guard activeBackend == .legacy, let audioPlayer, finishedPlayer === audioPlayer else { return }

    if sleepTimerOption == .endOfTrack {
      stop()
    } else if repeatMode == .one, let currentTrack {
      _ = loadAndPlay(currentTrack, at: currentQueueIndex)
    } else {
      next()
    }
  }

  fileprivate func handleDecodeError(_ failedPlayer: AVAudioPlayer, error: Error?) {
    guard activeBackend == .legacy, let audioPlayer, failedPlayer === audioPlayer else { return }
    reportRuntimeError("Audio decode failed: \(error?.localizedDescription ?? "Unknown decoder error")")
    clearUnplayableTrack()
  }

  private func configureSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      reportRuntimeError(source: "Audio Session", "Audio session setup failed: \(error.localizedDescription)")
    }
  }

  private func configureRemoteCommands() {
    let commands = MPRemoteCommandCenter.shared()

    commands.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.play() }
      return .success
    }
    commands.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.pause() }
      return .success
    }
    commands.nextTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.next() }
      return .success
    }
    commands.nextTrackCommand.isEnabled = true
    commands.previousTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.previous() }
      return .success
    }
    commands.previousTrackCommand.isEnabled = true

    // Keep the Lock Screen transport focused on track navigation. The in-app
    // 15-second controls still call skip(by:), but advertising skip commands
    // causes iOS to replace the primary previous/next layout with seek buttons.
    commands.skipForwardCommand.isEnabled = false
    commands.skipBackwardCommand.isEnabled = false

    commands.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      Task { @MainActor in self?.seek(to: event.positionTime) }
      return .success
    }
  }

  private func updateNowPlaying() {
    guard let track = currentTrack else { return }
    let showsArtwork = UserDefaults.standard.object(forKey: "showLockScreenArtwork") == nil
      || UserDefaults.standard.bool(forKey: "showLockScreenArtwork")
    ResonanceDiagnostics.shared.recordDeferred(
      "nowPlaying.update.begin",
      details: ["backend": activeBackendLabel, "artworkSetting": String(showsArtwork)]
    )
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: track.title,
      MPMediaItemPropertyArtist: track.artist,
      MPMediaItemPropertyAlbumTitle: track.album,
      MPMediaItemPropertyPlaybackDuration: duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0,
      MPNowPlayingInfoPropertyPlaybackQueueIndex: currentQueueIndex,
      MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count,
    ]

    if showsArtwork {
      if cachedNowPlayingArtworkTrackID == track.id, let artwork = cachedNowPlayingArtwork {
        info[MPMediaItemPropertyArtwork] = Self.makeNowPlayingArtwork(
          imageData: artwork.imageData,
          boundsSize: artwork.boundsSize
        )
      } else if let data = artworkData(for: track), nowPlayingArtworkTrackID != track.id {
        scheduleNowPlayingArtworkPreparation(data: data, trackID: track.id)
      }
    }
    ResonanceDiagnostics.shared.recordDeferred("nowPlaying.update.publish")
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func scheduleNowPlayingArtworkPreparation(data: Data, trackID: UUID) {
    nowPlayingArtworkTask?.cancel()
    nowPlayingArtworkTrackID = trackID
    nowPlayingArtworkTask = Task { @MainActor [weak self] in
      let prepared = await Task.detached(priority: .utility) {
        Self.prepareNowPlayingArtwork(data: data)
      }.value
      guard !Task.isCancelled, let self, self.currentTrack?.id == trackID else { return }
      self.nowPlayingArtworkTask = nil
      guard let prepared else {
        self.reportRuntimeError(source: "Lock Screen", "Album artwork could not be decoded for Now Playing.")
        ResonanceDiagnostics.shared.recordDeferred("nowPlaying.artwork.decodeFailed")
        return
      }
      self.cachedNowPlayingArtworkTrackID = trackID
      self.cachedNowPlayingArtwork = prepared
      ResonanceDiagnostics.shared.recordDeferred(
        "nowPlaying.artwork.handlerPrepared",
        details: ["bytes": String(prepared.imageData.count)]
      )
      self.publishNowPlayingArtwork(prepared, for: trackID)
    }
  }

  private func publishNowPlayingArtwork(_ artwork: PreparedNowPlayingArtwork, for trackID: UUID) {
    guard currentTrack?.id == trackID, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
    info[MPMediaItemPropertyArtwork] = Self.makeNowPlayingArtwork(
      imageData: artwork.imageData,
      boundsSize: artwork.boundsSize
    )
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func updateNowPlayingProgress() {
    guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
      updateNowPlaying()
      return
    }
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
    info[MPMediaItemPropertyPlaybackDuration] = duration
    info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentQueueIndex
    info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private var activeBackendLabel: String {
    switch activeBackend {
    case .none: "none"
    case .gapless: "gapless"
    case .legacy: "legacy"
    case .remote: "remote"
    }
  }

  private nonisolated static func prepareNowPlayingArtwork(data: Data) -> PreparedNowPlayingArtwork? {
    guard let image = UIImage(data: data)?.resonancePreparedNowPlayingImage(maxDimension: 1024),
      let imageData = image.jpegData(compressionQuality: 0.85)
    else {
      return nil
    }
    return PreparedNowPlayingArtwork(imageData: imageData, boundsSize: image.size)
  }

  private nonisolated static func makeNowPlayingArtwork(
    imageData: Data,
    boundsSize: CGSize
  ) -> MPMediaItemArtwork {
    MPMediaItemArtwork(boundsSize: boundsSize) { _ in
      UIImage(data: imageData) ?? UIImage()
    }
  }
}

private final class AudioPlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
  weak var owner: PlayerController?

  init(owner: PlayerController) {
    self.owner = owner
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor [weak owner] in
      owner?.handlePlaybackFinished(player, successfully: flag)
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    Task { @MainActor [weak owner] in
      owner?.handleDecodeError(player, error: error)
    }
  }
}

private final class RemotePlayerObserver: @unchecked Sendable {
  weak var owner: PlayerController?
  private var tokens: [NSObjectProtocol] = []

  init(owner: PlayerController) {
    self.owner = owner
  }

  func observe(_ item: AVPlayerItem) {
    observe([item])
  }

  func observe(_ items: [AVPlayerItem]) {
    stop()
    tokens = items.map { item in
      NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: item,
        queue: .main
      ) { [weak self, weak item] _ in
        guard let item else { return }
        let owner = self?.owner
        Task { @MainActor [weak owner] in
          owner?.handleRemotePlaybackFinished(item)
        }
      }
    }
  }

  func stop() {
    for token in tokens {
      NotificationCenter.default.removeObserver(token)
    }
    tokens.removeAll()
  }

  deinit { stop() }
}

extension UIImage {
  fileprivate func resonancePreparedNowPlayingImage(maxDimension: CGFloat) -> UIImage {
    let largestDimension = max(size.width, size.height)
    guard largestDimension > maxDimension, largestDimension > 0 else { return self }
    let scale = maxDimension / largestDimension
    let targetSize = CGSize(
      width: max(1, size.width * scale),
      height: max(1, size.height * scale)
    )
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }
}
