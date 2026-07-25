@preconcurrency import AVFoundation
@preconcurrency import AudioToolbox
import Foundation

/// Lower-level local-file playback backend. The current track and the opening
/// segment of the next track are scheduled on one player node. Large files use
/// a bounded partial schedule instead of being rejected by the preload budget.
/// A dedicated mixer converts multichannel sources to stereo before output.
final class GaplessAudioEngine: @unchecked Sendable {
  struct ScheduledTrack {
    let duration: TimeInterval
    let remainingStartFrame: AVAudioFramePosition?
    let channelCount: AVAudioChannelCount

    var isPartiallyPreloaded: Bool { remainingStartFrame != nil }
  }

  struct PreparedDurations {
    let current: ScheduledTrack
    let following: ScheduledTrack?
    let sourceSampleRate: Double
    let sourceFrameLength: AVAudioFramePosition
    let graphSampleRate: Double
    let outputSampleRate: Double
  }

  enum EngineError: LocalizedError {
    case missingFile(URL)
    case emptyAudioFile(URL)
    case incompatiblePreloadChannels(expected: AVAudioChannelCount, actual: AVAudioChannelCount)
    case incompatiblePreloadSampleRates(expected: Double, actual: Double)
    case matrixConfigurationFailed(OSStatus)

    var errorDescription: String? {
      switch self {
      case .missingFile(let url): return "Audio file is missing: \(url.lastPathComponent)"
      case .emptyAudioFile(let url): return "Audio file contains no playable frames: \(url.lastPathComponent)"
      case .incompatiblePreloadChannels(let expected, let actual):
        return "Gapless preload requires the same channel count (expected \(expected), found \(actual))."
      case .incompatiblePreloadSampleRates(let expected, let actual):
        return "Gapless preload requires the same sample rate (expected \(expected), found \(actual))."
      case .matrixConfigurationFailed(let status):
        return "The explicit surround downmix matrix could not be configured (OSStatus \(status))."
      }
    }
  }

  typealias CompletionHandler = @Sendable (_ trackID: UUID, _ generation: Int) -> Void

  private let engine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  private let matrixMixer: AVAudioUnit?
  private let stereoMixer = AVAudioMixerNode()
  private let meterState = AudioMeterState()
  private let retainedFiles = RetainedAudioFiles()
  private var completionHandler: CompletionHandler?
  private var configuredSourceChannels: AVAudioChannelCount = 0
  private var configuredSourceSampleRate: Double = 0
  private var configuredGraphSampleRate: Double = 0
  private var configuredOutputSampleRate: Double = 0
  private(set) var isPrepared = false
  private(set) var downmixRoutingDescription = "Automatic stereo routing"

  var volume: Float {
    get { playerNode.volume }
    set { playerNode.volume = min(max(newValue, 0), 1) }
  }

  var isPlaying: Bool { playerNode.isPlaying }
  var isEngineRunning: Bool { engine.isRunning }
  var meterLevel: Double { meterState.value }
  var outputChannelCount: AVAudioChannelCount { 2 }

  init(completionHandler: CompletionHandler? = nil) {
    self.completionHandler = completionHandler
    self.matrixMixer = Self.instantiateMatrixMixer()
    engine.attach(playerNode)
    if let matrixMixer {
      engine.attach(matrixMixer)
    }
    engine.attach(stereoMixer)

    let deviceFormat = engine.outputNode.inputFormat(forBus: 0)
    let sampleRate = deviceFormat.sampleRate > 0 ? deviceFormat.sampleRate : 48_000
    let stereoFormat = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate,
      channels: outputChannelCount
    )
    engine.connect(stereoMixer, to: engine.mainMixerNode, format: stereoFormat)
    installMeterTap()
  }

  func setCompletionHandler(_ handler: CompletionHandler?) {
    completionHandler = handler
  }

  @discardableResult
  func prepare(
    currentTrackID: UUID,
    currentURL: URL,
    startTime: TimeInterval,
    followingTrackID: UUID?,
    followingURL: URL?,
    preloadBudgetBytes: Int64,
    generation: Int
  ) throws -> PreparedDurations {
    stop(resetEngine: true)

    let currentFile = try openFile(at: currentURL)
    let matrixConfiguration = configureSignalPath(for: currentFile.processingFormat)
    try startEngineIfNeeded()
    if let matrixConfiguration {
      try configureExplicitDownmixMatrix(
        matrixConfiguration.unit,
        inputChannels: matrixConfiguration.inputChannels,
        outputChannels: matrixConfiguration.outputChannels
      )
    }
    let currentDuration = Self.duration(of: currentFile)
    let safeStart = min(max(0, startTime), max(0, currentDuration - 0.05))
    let startFrame = AVAudioFramePosition(safeStart * currentFile.processingFormat.sampleRate)
    scheduleCompleteTrack(
      file: currentFile,
      trackID: currentTrackID,
      startingFrame: startFrame,
      generation: generation
    )

    let current = ScheduledTrack(
      duration: currentDuration,
      remainingStartFrame: nil,
      channelCount: currentFile.processingFormat.channelCount
    )

    var following: ScheduledTrack?
    if let followingTrackID, let followingURL {
      following = try? appendPreloaded(
        trackID: followingTrackID,
        url: followingURL,
        preloadBudgetBytes: preloadBudgetBytes,
        generation: generation
      )
    }

    playerNode.play()
    isPrepared = true
    return PreparedDurations(
      current: current,
      following: following,
      sourceSampleRate: currentFile.processingFormat.sampleRate,
      sourceFrameLength: currentFile.length,
      graphSampleRate: configuredGraphSampleRate,
      outputSampleRate: configuredOutputSampleRate
    )
  }

  /// Schedules either the complete next track or a bounded opening segment.
  /// When the file is larger than the selected budget, the controller appends
  /// the remainder as soon as the track boundary is crossed.
  @discardableResult
  func appendPreloaded(
    trackID: UUID,
    url: URL,
    preloadBudgetBytes: Int64,
    generation: Int
  ) throws -> ScheduledTrack {
    let file = try openFile(at: url)
    guard configuredSourceChannels == 0 || file.processingFormat.channelCount == configuredSourceChannels else {
      throw EngineError.incompatiblePreloadChannels(
        expected: configuredSourceChannels,
        actual: file.processingFormat.channelCount
      )
    }
    guard configuredSourceSampleRate == 0
      || Self.sampleRatesMatch(file.processingFormat.sampleRate, configuredSourceSampleRate)
    else {
      throw EngineError.incompatiblePreloadSampleRates(
        expected: configuredSourceSampleRate,
        actual: file.processingFormat.sampleRate
      )
    }
    let duration = Self.duration(of: file)
    let headFrameCount = preloadFrameCount(
      for: file,
      url: url,
      preloadBudgetBytes: preloadBudgetBytes
    )

    if headFrameCount >= file.length {
      scheduleCompleteTrack(
        file: file,
        trackID: trackID,
        startingFrame: 0,
        generation: generation
      )
      return ScheduledTrack(
        duration: duration,
        remainingStartFrame: nil,
        channelCount: file.processingFormat.channelCount
      )
    }

    let scheduledHeadFrames = min(headFrameCount, AVAudioFramePosition(UInt32.max))
    let token = retainedFiles.retain(file)
    playerNode.scheduleSegment(
      file,
      startingFrame: 0,
      frameCount: AVAudioFrameCount(scheduledHeadFrames),
      at: nil,
      completionCallbackType: .dataPlayedBack
    ) { [weak self] _ in
      self?.retainedFiles.release(token)
    }

    return ScheduledTrack(
      duration: duration,
      remainingStartFrame: scheduledHeadFrames,
      channelCount: file.processingFormat.channelCount
    )
  }

  /// Appends the unscheduled remainder of a partially preloaded track. This is
  /// called immediately after the preceding track reaches its audio boundary,
  /// while the already-scheduled opening segment is playing.
  @discardableResult
  func appendRemainder(
    trackID: UUID,
    url: URL,
    startingFrame: AVAudioFramePosition,
    generation: Int
  ) throws -> TimeInterval {
    let file = try openFile(at: url)
    guard configuredSourceChannels == 0 || file.processingFormat.channelCount == configuredSourceChannels else {
      throw EngineError.incompatiblePreloadChannels(
        expected: configuredSourceChannels,
        actual: file.processingFormat.channelCount
      )
    }
    guard configuredSourceSampleRate == 0
      || Self.sampleRatesMatch(file.processingFormat.sampleRate, configuredSourceSampleRate)
    else {
      throw EngineError.incompatiblePreloadSampleRates(
        expected: configuredSourceSampleRate,
        actual: file.processingFormat.sampleRate
      )
    }
    scheduleCompleteTrack(
      file: file,
      trackID: trackID,
      startingFrame: startingFrame,
      generation: generation
    )
    return Self.duration(of: file)
  }

  func play() throws {
    guard isPrepared else { return }
    try startEngineIfNeeded()
    playerNode.play()
  }

  func pause() {
    playerNode.pause()
  }

  func stop(resetEngine: Bool = false) {
    playerNode.stop()
    retainedFiles.removeAll()
    isPrepared = false
    configuredSourceChannels = 0
    configuredSourceSampleRate = 0
    configuredGraphSampleRate = 0
    configuredOutputSampleRate = 0
    downmixRoutingDescription = "Automatic stereo routing"
    stereoMixer.outputVolume = 1
    meterState.value = 0
    if resetEngine {
      // Stop the render graph before resetting it. Resetting a running engine
      // after a partially configured Matrix Mixer can leave the audio unit in
      // an invalid state on device.
      if engine.isRunning { engine.stop() }
      engine.reset()
    }
  }

  /// Tears down a preparation attempt that failed while the graph was only
  /// partially configured. The controller quarantines this engine instance
  /// after calling this method, so no subsequent playback reuses the matrix.
  func abandonFailedPreparation() {
    playerNode.stop()
    if engine.isRunning { engine.stop() }
    retainedFiles.removeAll()
    engine.disconnectNodeOutput(playerNode)
    engine.disconnectNodeInput(stereoMixer)
    if let matrixMixer {
      engine.disconnectNodeInput(matrixMixer)
      engine.disconnectNodeOutput(matrixMixer)
    }
    isPrepared = false
    configuredSourceChannels = 0
    configuredSourceSampleRate = 0
    configuredGraphSampleRate = 0
    configuredOutputSampleRate = 0
    downmixRoutingDescription = "Automatic stereo routing"
    stereoMixer.outputVolume = 1
    meterState.value = 0
  }

  private func configureSignalPath(
    for sourceFormat: AVAudioFormat
  ) -> (unit: AVAudioUnit, inputChannels: Int, outputChannels: Int)? {
    engine.disconnectNodeOutput(playerNode)
    engine.disconnectNodeInput(stereoMixer)
    if let matrixMixer {
      engine.disconnectNodeInput(matrixMixer)
      engine.disconnectNodeOutput(matrixMixer)
    }

    configuredSourceChannels = sourceFormat.channelCount
    configuredSourceSampleRate = sourceFormat.sampleRate
    let deviceFormat = engine.outputNode.inputFormat(forBus: 0)
    let deviceSampleRate = deviceFormat.sampleRate > 0 ? deviceFormat.sampleRate : 0
    let sampleRate = sourceFormat.sampleRate > 0
      ? sourceFormat.sampleRate
      : (deviceSampleRate > 0 ? deviceSampleRate : 48_000)
    configuredGraphSampleRate = sampleRate
    configuredOutputSampleRate = deviceSampleRate > 0 ? deviceSampleRate : sampleRate
    guard let stereoFormat = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate,
      channels: outputChannelCount
    ) else {
      engine.connect(playerNode, to: stereoMixer, format: sourceFormat)
      downmixRoutingDescription = "System stereo routing"
      return nil
    }

    // Keep the file's native sample rate through the player, matrix, and
    // stereo mixer. The main mixer is the first graph stage allowed to
    // convert to the current hardware route. Forcing a 96 kHz FLAC through a
    // 48 kHz matrix output can make the file render at the wrong speed while
    // still reporting a running engine and non-zero meter.
    engine.disconnectNodeOutput(stereoMixer)
    engine.connect(stereoMixer, to: engine.mainMixerNode, format: stereoFormat)

    guard sourceFormat.channelCount > 2, let matrixMixer else {
      engine.connect(playerNode, to: stereoMixer, format: sourceFormat)
      stereoMixer.outputVolume = 1
      downmixRoutingDescription = sourceFormat.channelCount == 1
        ? "Mono duplicated to left and right"
        : "Native stereo: left → left, right → right"
      return nil
    }

    engine.connect(playerNode, to: matrixMixer, format: sourceFormat)
    engine.connect(matrixMixer, to: stereoMixer, format: stereoFormat)
    // Multiple source channels are summed into each stereo output. Preserve
    // headroom so full-scale center, LFE, and surround content doesn't clip.
    stereoMixer.outputVolume = 0.5
    if sourceFormat.channelCount == 6 {
      downmixRoutingDescription = "Explicit 5.1: FL + rear left → L; FR + rear right → R; center + LFE → L/R"
    } else {
      downmixRoutingDescription = "Explicit \(sourceFormat.channelCount)-channel matrix → stereo"
    }
    return (
      unit: matrixMixer,
      inputChannels: Int(sourceFormat.channelCount),
      outputChannels: Int(outputChannelCount)
    )
  }

  private func configureExplicitDownmixMatrix(
    _ matrixNode: AVAudioUnit,
    inputChannels: Int,
    outputChannels: Int
  ) throws {
    guard outputChannels == 2 else { return }
    let unit = matrixNode.audioUnit

    // A matrix mixer has four independent gain stages. Cross-point gains are
    // not audible unless the matrix master, every input channel, and every
    // output channel are enabled as well. Those defaults are not reliable
    // after an AVAudioEngine reset, which previously let playback advance
    // with a silent render graph.
    try setMatrixGain(
      unit,
      scope: kAudioUnitScope_Global,
      element: AudioUnitElement(UInt32.max),
      gain: 1
    )
    for input in 0..<inputChannels {
      try setMatrixGain(
        unit,
        scope: kAudioUnitScope_Input,
        element: AudioUnitElement(input),
        gain: 1
      )
    }
    for output in 0..<outputChannels {
      try setMatrixGain(
        unit,
        scope: kAudioUnitScope_Output,
        element: AudioUnitElement(output),
        gain: 1
      )
    }

    // Matrix cross-points encode input in the high 16 bits and output in the
    // low 16 bits of the global-scope element number.
    for input in 0..<inputChannels {
      for output in 0..<outputChannels {
        try setMatrixGain(unit, input: input, output: output, gain: 0)
      }
    }

    func route(_ input: Int, to output: Int, gain: Float) throws {
      guard input < inputChannels, output < outputChannels else { return }
      try setMatrixGain(unit, input: input, output: output, gain: gain)
    }

    try route(0, to: 0, gain: 1.0)       // front left → left
    try route(1, to: 1, gain: 1.0)       // front right → right

    if inputChannels == 3 {
      try route(2, to: 0, gain: 0.7071)  // center → both
      try route(2, to: 1, gain: 0.7071)
      return
    }

    if inputChannels == 4 {
      try route(2, to: 0, gain: 0.7071)  // rear left → left
      try route(3, to: 1, gain: 0.7071)  // rear right → right
      return
    }

    // FLAC 5.1 channel order is FL, FR, center, LFE, rear-left, rear-right.
    if inputChannels >= 5 {
      try route(2, to: 0, gain: 0.7071)  // center → both
      try route(2, to: 1, gain: 0.7071)
      try route(3, to: 0, gain: 0.5)     // LFE → both
      try route(3, to: 1, gain: 0.5)
      try route(4, to: 0, gain: 0.7071)  // rear left → left only
    }
    if inputChannels >= 6 {
      try route(5, to: 1, gain: 0.7071)  // rear right → right only
    }
    if inputChannels >= 7 {
      try route(6, to: 0, gain: 0.7071)  // additional left surround → left
    }
    if inputChannels >= 8 {
      try route(7, to: 1, gain: 0.7071)  // additional right surround → right
    }

    if inputChannels > 8 {
      for input in 8..<inputChannels {
        try route(input, to: input.isMultiple(of: 2) ? 0 : 1, gain: 0.5)
      }
    }
  }

  private func setMatrixGain(
    _ unit: AudioUnit,
    input: Int,
    output: Int,
    gain: Float
  ) throws {
    let crossPoint = AudioUnitElement((input << 16) | output)
    try setMatrixGain(
      unit,
      scope: kAudioUnitScope_Global,
      element: crossPoint,
      gain: gain
    )
  }

  private func setMatrixGain(
    _ unit: AudioUnit,
    scope: AudioUnitScope,
    element: AudioUnitElement,
    gain: Float
  ) throws {
    let status = AudioUnitSetParameter(
      unit,
      kMatrixMixerParam_Volume,
      scope,
      element,
      AudioUnitParameterValue(gain),
      0
    )
    guard status == noErr else { throw EngineError.matrixConfigurationFailed(status) }
  }

  private static func instantiateMatrixMixer() -> AVAudioUnit? {
    let description = AudioComponentDescription(
      componentType: kAudioUnitType_Mixer,
      componentSubType: kAudioUnitSubType_MatrixMixer,
      componentManufacturer: kAudioUnitManufacturer_Apple,
      componentFlags: 0,
      componentFlagsMask: 0
    )
    let result = AudioUnitInstantiationResult()
    let semaphore = DispatchSemaphore(value: 0)
    AVAudioUnit.instantiate(with: description, options: []) { unit, _ in
      result.store(unit)
      semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 3) == .success else { return nil }
    return result.load()
  }

  private func startEngineIfNeeded() throws {
    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }
  }

  private func openFile(at url: URL) throws -> AVAudioFile {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw EngineError.missingFile(url)
    }
    let file = try AVAudioFile(forReading: url)
    guard file.length > 0 else { throw EngineError.emptyAudioFile(url) }
    return file
  }

  private func scheduleCompleteTrack(
    file: AVAudioFile,
    trackID: UUID,
    startingFrame: AVAudioFramePosition,
    generation: Int
  ) {
    let safeStart = min(max(0, startingFrame), max(0, file.length - 1))
    let token = retainedFiles.retain(file)
    var cursor = safeStart

    while cursor < file.length {
      let remaining = file.length - cursor
      let segmentFrames = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))
      let isFinalSegment = cursor + AVAudioFramePosition(segmentFrames) >= file.length

      if isFinalSegment {
        playerNode.scheduleSegment(
          file,
          startingFrame: cursor,
          frameCount: segmentFrames,
          at: nil,
          completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
          self?.retainedFiles.release(token)
          self?.completionHandler?(trackID, generation)
        }
      } else {
        playerNode.scheduleSegment(
          file,
          startingFrame: cursor,
          frameCount: segmentFrames,
          at: nil,
          completionCallbackType: .dataConsumed
        ) { _ in }
      }
      cursor += AVAudioFramePosition(segmentFrames)
    }
  }

  private func preloadFrameCount(
    for file: AVAudioFile,
    url: URL,
    preloadBudgetBytes: Int64
  ) -> AVAudioFramePosition {
    let safeBudget = max(Int64(1_048_576), preloadBudgetBytes)
    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    let minimumLeadFrames = AVAudioFramePosition(file.processingFormat.sampleRate * 12)

    guard let fileSize, fileSize > safeBudget else {
      return file.length
    }

    let ratio = min(1, Double(safeBudget) / Double(fileSize))
    let proportionalFrames = AVAudioFramePosition(Double(file.length) * ratio)
    return min(file.length, max(minimumLeadFrames, proportionalFrames))
  }

  private static func duration(of file: AVAudioFile) -> TimeInterval {
    let rate = file.processingFormat.sampleRate
    guard rate > 0 else { return 0 }
    return Double(file.length) / rate
  }

  private static func sampleRatesMatch(_ lhs: Double, _ rhs: Double) -> Bool {
    lhs > 0 && rhs > 0 && abs(lhs - rhs) < 0.5
  }

  private func installMeterTap() {
    stereoMixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [meterState] buffer, _ in
      guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else {
        meterState.value = 0
        return
      }

      let frameCount = Int(buffer.frameLength)
      let channelCount = max(1, Int(buffer.format.channelCount))
      let bufferCount = buffer.format.isInterleaved ? 1 : channelCount
      let samplesPerBuffer = buffer.format.isInterleaved ? frameCount * channelCount : frameCount
      var sumSquares: Float = 0
      for channel in 0..<bufferCount {
        let samples = channels[channel]
        for frame in 0..<samplesPerBuffer {
          let sample = samples[frame]
          sumSquares += sample * sample
        }
      }
      let divisor = Float(max(1, samplesPerBuffer * bufferCount))
      let rms = sqrt(max(0, sumSquares / divisor))
      meterState.value = min(1, max(0, Double(rms) * 4.5))
    }
  }
}

private final class AudioUnitInstantiationResult: @unchecked Sendable {
  private let lock = NSLock()
  private var unit: AVAudioUnit?

  func store(_ unit: AVAudioUnit?) {
    lock.lock()
    self.unit = unit
    lock.unlock()
  }

  func load() -> AVAudioUnit? {
    lock.lock()
    defer { lock.unlock() }
    return unit
  }
}

private final class AudioMeterState: @unchecked Sendable {
  private let lock = NSLock()
  private var storedValue = 0.0

  var value: Double {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storedValue
    }
    set {
      lock.lock()
      storedValue = newValue
      lock.unlock()
    }
  }
}

private final class RetainedAudioFiles: @unchecked Sendable {
  private let lock = NSLock()
  private var files: [UUID: AVAudioFile] = [:]

  func retain(_ file: AVAudioFile) -> UUID {
    let token = UUID()
    lock.lock()
    files[token] = file
    lock.unlock()
    return token
  }

  func release(_ token: UUID) {
    lock.lock()
    files[token] = nil
    lock.unlock()
  }

  func removeAll() {
    lock.lock()
    files.removeAll(keepingCapacity: true)
    lock.unlock()
  }
}
