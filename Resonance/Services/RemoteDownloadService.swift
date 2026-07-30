import Foundation

struct RemoteDownloadProgress: Identifiable, Sendable {
    let id: UUID
    let title: String
    let completed: Int
    let total: Int
    let state: State

    enum State: String, Sendable {
        case queued
        case downloading
        case completed
        case skipped
        case failed
        case cancelled
    }

    var fraction: Double {
        guard total > 0 else { return state == .completed || state == .skipped ? 1 : 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

enum RemoteDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The remote track has no downloadable stream URL."
        case .invalidResponse: "The remote server returned an invalid download response."
        case let .httpStatus(code): "The remote server returned HTTP \(code)."
        case .emptyResponse: "The remote server returned an empty audio file."
        case .fileWriteFailed: "The downloaded audio file could not be saved to the local library."
        }
    }
}

private extension Notification.Name {
    static let resonanceBackgroundDownloadProgress = Notification.Name("Resonance.backgroundDownloadProgress")
    static let resonanceBackgroundDownloadFinished = Notification.Name("Resonance.backgroundDownloadFinished")
    static let resonanceBackgroundDownloadFailed = Notification.Name("Resonance.backgroundDownloadFailed")
}

struct RemoteBackgroundDownloadRecord: Codable, Sendable {
    let taskIdentifier: Int
    let trackID: UUID
    let replacingExisting: Bool
    var inboxFileName: String?
}

struct RemoteBackgroundTaskSnapshot: Sendable {
    let taskIdentifier: Int
    let taskDescription: String?
}

private struct RemoteBackgroundNotification: Sendable {
    let taskIdentifier: Int
    let trackID: UUID
    let completed: Int64
    let total: Int64
    let inboxFileName: String?

    init?(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let taskIdentifier = userInfo["taskIdentifier"] as? Int,
              let trackID = UUID(uuidString: userInfo["trackID"] as? String ?? "") else { return nil }
        self.taskIdentifier = taskIdentifier
        self.trackID = trackID
        self.completed = (userInfo["completed"] as? NSNumber)?.int64Value ?? 0
        self.total = (userInfo["total"] as? NSNumber)?.int64Value ?? 0
        self.inboxFileName = userInfo["inboxFileName"] as? String
    }
}

final class RemoteBackgroundDownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = RemoteBackgroundDownloadSession()
    static let sessionIdentifier = "com.example.ResonancePrototype.remote-downloads.v1"

    private static let recordsKey = "resonance.remoteBackgroundDownloadRecords"
    private static let inboxDirectoryName = "RemoteDownloadInbox"

    private let lock = NSLock()
    private let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.example.ResonancePrototype.remote-downloads.delegate"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()
    private var backgroundEventsCompletionHandler: (() -> Void)?

    override init() {
        super.init()
        ensureInboxDirectory()
        _ = session
    }

    func setBackgroundEventsCompletionHandler(_ handler: @escaping () -> Void) {
        lock.withLock {
            backgroundEventsCompletionHandler = handler
        }
    }

    @discardableResult
    func enqueue(
        trackID: UUID,
        url: URL,
        replacingExisting: Bool
    ) -> Int? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = session.downloadTask(with: request)
        task.taskDescription = trackID.uuidString
        let record = RemoteBackgroundDownloadRecord(
            taskIdentifier: task.taskIdentifier,
            trackID: trackID,
            replacingExisting: replacingExisting,
            inboxFileName: nil
        )
        updateRecord(record)
        task.resume()
        return task.taskIdentifier
    }

    func cancel(taskIdentifier: Int) {
        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskIdentifier == taskIdentifier })?.cancel()
        }
    }

    func cancelAll() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    func records() -> [RemoteBackgroundDownloadRecord] {
        lock.withLock {
            loadRecords()
        }
    }

    func activeTaskSnapshots(completion: @escaping @Sendable ([RemoteBackgroundTaskSnapshot]) -> Void) {
        session.getAllTasks { tasks in
            let snapshots = tasks.map {
                RemoteBackgroundTaskSnapshot(
                    taskIdentifier: $0.taskIdentifier,
                    taskDescription: $0.taskDescription
                )
            }
            completion(snapshots)
        }
    }

    func acknowledge(taskIdentifier: Int) {
        lock.withLock {
            var records = loadRecords()
            records.removeAll { $0.taskIdentifier == taskIdentifier }
            saveRecords(records)
        }
    }

    func removeInboxFile(named fileName: String) {
        let url = inboxDirectoryURL().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func urlForInboxFile(named fileName: String) -> URL {
        inboxDirectoryURL().appendingPathComponent(fileName)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let record = record(for: downloadTask.taskIdentifier) else { return }
        NotificationCenter.default.post(
            name: .resonanceBackgroundDownloadProgress,
            object: nil,
            userInfo: [
                "taskIdentifier": downloadTask.taskIdentifier,
                "trackID": record.trackID.uuidString,
                "completed": totalBytesWritten,
                "total": totalBytesExpectedToWrite
            ]
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let record = record(for: downloadTask.taskIdentifier) else { return }
        guard let http = downloadTask.response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: location)
            postFailure(for: record, code: (downloadTask.response as? HTTPURLResponse)?.statusCode ?? -1)
            return
        }

        let extensionName = Self.fileExtension(
            mimeType: downloadTask.response?.mimeType,
            fallback: downloadTask.originalRequest?.url?.pathExtension ?? ""
        )
        let fileName = "\(record.taskIdentifier).\(extensionName)"
        let destination = inboxDirectoryURL().appendingPathComponent(fileName)
        do {
            ensureInboxDirectory()
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            updateRecord(
                RemoteBackgroundDownloadRecord(
                    taskIdentifier: record.taskIdentifier,
                    trackID: record.trackID,
                    replacingExisting: record.replacingExisting,
                    inboxFileName: fileName
                )
            )
            NotificationCenter.default.post(
                name: .resonanceBackgroundDownloadFinished,
                object: nil,
                userInfo: [
                    "taskIdentifier": record.taskIdentifier,
                    "trackID": record.trackID.uuidString,
                    "inboxFileName": fileName
                ]
            )
        } catch {
            try? FileManager.default.removeItem(at: location)
            postFailure(for: record, code: (error as NSError).code)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let record = record(for: task.taskIdentifier) else { return }
        postFailure(for: record, code: (error as NSError).code)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = lock.withLock {
            defer { backgroundEventsCompletionHandler = nil }
            return backgroundEventsCompletionHandler
        }
        guard let handler else { return }
        handler()
    }

    private func postFailure(for record: RemoteBackgroundDownloadRecord, code: Int) {
        NotificationCenter.default.post(
            name: .resonanceBackgroundDownloadFailed,
            object: nil,
            userInfo: [
                "taskIdentifier": record.taskIdentifier,
                "trackID": record.trackID.uuidString,
                "errorCode": code
            ]
        )
    }

    private func record(for taskIdentifier: Int) -> RemoteBackgroundDownloadRecord? {
        lock.withLock {
            loadRecords().first { $0.taskIdentifier == taskIdentifier }
        }
    }

    private func updateRecord(_ record: RemoteBackgroundDownloadRecord) {
        lock.withLock {
            var records = loadRecords()
            records.removeAll { $0.taskIdentifier == record.taskIdentifier }
            records.append(record)
            saveRecords(records)
        }
    }

    private func loadRecords() -> [RemoteBackgroundDownloadRecord] {
        guard let data = UserDefaults.standard.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([RemoteBackgroundDownloadRecord].self, from: data)
        else { return [] }
        return records
    }

    private func saveRecords(_ records: [RemoteBackgroundDownloadRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Self.recordsKey)
    }

    private func inboxDirectoryURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport.appendingPathComponent(Self.inboxDirectoryName, isDirectory: true)
    }

    private func ensureInboxDirectory() {
        try? FileManager.default.createDirectory(
            at: inboxDirectoryURL(),
            withIntermediateDirectories: true
        )
    }

    private static func fileExtension(mimeType: String?, fallback: String) -> String {
        let mapped: String
        switch mimeType?.lowercased() {
        case "audio/flac", "audio/x-flac": mapped = "flac"
        case "audio/mpeg", "audio/mp3": mapped = "mp3"
        case "audio/mp4", "audio/x-m4a": mapped = "m4a"
        case "audio/aac": mapped = "aac"
        case "audio/wav", "audio/x-wav": mapped = "wav"
        case "audio/aiff", "audio/x-aiff": mapped = "aiff"
        case "audio/ogg", "audio/opus": mapped = "ogg"
        default: mapped = ""
        }
        let candidate = mapped.isEmpty ? fallback.lowercased() : mapped
        return MetadataReader.supportedExtensions.contains(candidate) ? candidate : "mp3"
    }
}

@MainActor
final class RemoteDownloadManager: ObservableObject {
    private static let persistedQueueIDsKey = "resonance.remoteDownloadQueueIDs"
    private static let experimentalBackgroundDownloadsKey = "experimentalBackgroundDownloads"

    @Published private(set) var isDownloading = false
    @Published private(set) var currentTitle = ""
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var currentCompletedBytes: Int64 = 0
    @Published private(set) var currentTotalBytes: Int64 = 0
    @Published private(set) var lastMessage = ""
    @Published private(set) var itemProgress: [UUID: RemoteDownloadProgress] = [:]
    @Published private(set) var downloadQueue: [RemoteDownloadProgress] = []
    @Published private(set) var pendingReplacementCount = 0
    @Published private(set) var pendingReplacementDescription = ""

    var hasPersistedQueue: Bool {
        !persistedQueueIDs().isEmpty
    }

    private struct DownloadResult: Sendable {
        let bytes: Int64
        let skipped: Bool
        let destination: URL
    }

    private var downloadTask: Task<Void, Never>?
    private var activeWorker: Task<DownloadResult, Error>?
    private var activeTrackID: UUID?
    private var individuallyCancelledTrackIDs: Set<UUID> = []
    private var requeueRequests: [UUID: RemoteTrackItem] = [:]
    private var activeTracksByID: [UUID: RemoteTrackItem] = [:]
    private var pendingTracks: [RemoteTrackItem] = []
    private var pendingNewTracks: [RemoteTrackItem] = []
    private var artworkByAlbumKey: [String: Data] = [:]
    private var artworkByTrackID: [UUID: Data] = [:]
    private weak var pendingLibrary: LibraryStore?
    private let backgroundSession = RemoteBackgroundDownloadSession.shared
    private var backgroundObservers: [NSObjectProtocol] = []
    private var backgroundTaskIdentifiers: [UUID: Int] = [:]
    private var backgroundTrackIDsByTask: [Int: UUID] = [:]
    private var backgroundReplacingExisting: [UUID: Bool] = [:]
    private var backgroundFinalizing: Set<UUID> = []

    init() {
        let center = NotificationCenter.default
        backgroundObservers = [
            center.addObserver(
                forName: .resonanceBackgroundDownloadProgress,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let event = RemoteBackgroundNotification(notification: note) else { return }
                Task { @MainActor [weak self, event] in
                    self?.handleBackgroundProgress(event)
                }
            },
            center.addObserver(
                forName: .resonanceBackgroundDownloadFinished,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let event = RemoteBackgroundNotification(notification: note) else { return }
                Task { @MainActor [weak self, event] in
                    self?.handleBackgroundFinished(event)
                }
            },
            center.addObserver(
                forName: .resonanceBackgroundDownloadFailed,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let event = RemoteBackgroundNotification(notification: note) else { return }
                Task { @MainActor [weak self, event] in
                    self?.handleBackgroundFailure(event)
                }
            }
        ]
    }

    func rememberArtwork(_ data: Data, for tracks: [RemoteTrackItem]) {
        for albumKey in Set(tracks.map(\.albumKey)) {
            artworkByAlbumKey[albumKey] = data
        }
    }

    func rememberArtwork(_ dataByTrackID: [UUID: Data], for tracks: [RemoteTrackItem]) {
        for track in tracks {
            guard let data = dataByTrackID[track.id], !data.isEmpty else { continue }
            artworkByTrackID[track.id] = data
        }
        if let first = dataByTrackID.values.first, !first.isEmpty {
            rememberArtwork(first, for: tracks)
        }
    }

    func requestDownload(_ remoteTracks: [RemoteTrackItem], into library: LibraryStore) {
        let tracks = remoteTracks.reduce(into: [RemoteTrackItem]()) { result, track in
            if !result.contains(where: { $0.id == track.id }) { result.append(track) }
        }
        guard !tracks.isEmpty, !isDownloading else {
            if isDownloading { lastMessage = "A download is already in progress" }
            return
        }

        ResonanceDiagnostics.shared.recordDeferred(
            "download.request",
            details: ["trackCount": String(tracks.count), "active": String(isDownloading)]
        )

        let duplicates = tracks.filter {
            Self.existingDestinationURL(for: $0, in: library.sharedMusicFolderURL) != nil
        }
        if !duplicates.isEmpty {
            pendingTracks = duplicates
            pendingNewTracks = tracks.filter { track in
                !duplicates.contains(where: { $0.id == track.id })
            }
            pendingLibrary = library
            pendingReplacementCount = duplicates.count
            let duplicateText = duplicates.count == 1
                ? "One local file with the same name already exists."
                : "\(duplicates.count) local files with the same names already exist."
            let newText = pendingNewTracks.isEmpty
                ? ""
                : " \(pendingNewTracks.count) other download\(pendingNewTracks.count == 1 ? "" : "s") will be available either way."
            pendingReplacementDescription = "\(duplicateText) Replace the existing file\(duplicates.count == 1 ? "" : "s")?\(newText)"
            return
        }

        startDownload(tracks, into: library, replacingExisting: false)
    }

    func confirmReplacement() {
        guard !pendingTracks.isEmpty, let library = pendingLibrary else {
            cancelPendingReplacement()
            return
        }
        let tracks = pendingTracks
        cancelPendingReplacement()
        startDownload(tracks, into: library, replacingExisting: true)
    }

    func keepExistingAndDownloadNew() {
        guard let library = pendingLibrary else {
            cancelPendingReplacement()
            return
        }
        let tracks = pendingNewTracks
        cancelPendingReplacement()
        guard !tracks.isEmpty else {
            lastMessage = "The selected files are already on this iPhone"
            return
        }
        startDownload(tracks, into: library, replacingExisting: false)
    }

    func cancelPendingReplacement() {
        pendingTracks = []
        pendingNewTracks = []
        pendingLibrary = nil
        pendingReplacementCount = 0
        pendingReplacementDescription = ""
    }

    func cancel() {
        guard isDownloading else { return }
        if !backgroundTaskIdentifiers.isEmpty {
            backgroundSession.cancelAll()
            let cancellable = itemProgress.values.filter {
                $0.state == .queued || $0.state == .downloading
            }
            for progress in cancellable {
                individuallyCancelledTrackIDs.insert(progress.id)
                setProgress(
                    RemoteDownloadProgress(
                        id: progress.id,
                        title: progress.title,
                        completed: progress.completed,
                        total: progress.total,
                        state: .cancelled
                    )
                )
            }
            completedCount = itemProgress.count
            backgroundTaskIdentifiers.removeAll()
            clearPersistedQueue()
            finishBackgroundBatch(message: "Download cancelled")
            ResonanceDiagnostics.shared.recordDeferred("download.cancelAll")
            return
        }
        activeWorker?.cancel()
        downloadTask?.cancel()
        clearPersistedQueue()
        ResonanceDiagnostics.shared.recordDeferred("download.cancelAll")
        lastMessage = "Cancelling download…"
    }

    func cancelDownload(_ id: UUID) {
        guard isDownloading, let current = itemProgress[id] else { return }
        guard current.state == .queued || current.state == .downloading else { return }
        individuallyCancelledTrackIDs.insert(id)
        removePersistedTrack(id)
        if let taskIdentifier = backgroundTaskIdentifiers.removeValue(forKey: id) {
            backgroundTrackIDsByTask[taskIdentifier] = id
            backgroundSession.cancel(taskIdentifier: taskIdentifier)
            setProgress(
                RemoteDownloadProgress(
                    id: current.id,
                    title: current.title,
                    completed: current.completed,
                    total: current.total,
                    state: .cancelled
                )
            )
            completedCount += 1
            finishBackgroundBatchIfNeeded()
            return
        }
        if activeTrackID == id {
            activeWorker?.cancel()
        } else {
            setProgress(
                RemoteDownloadProgress(
                    id: current.id,
                    title: current.title,
                    completed: current.completed,
                    total: current.total,
                    state: .cancelled
                )
            )
            completedCount += 1
        }
    }

    func requeueDownload(_ id: UUID) {
        guard isDownloading, let current = itemProgress[id], current.state == .cancelled,
              let track = activeTracksByID[id] else { return }
        individuallyCancelledTrackIDs.remove(id)
        if experimentalBackgroundDownloadsEnabled || !backgroundTaskIdentifiers.isEmpty {
            setProgress(
                RemoteDownloadProgress(
                    id: current.id,
                    title: current.title,
                    completed: 0,
                    total: 0,
                    state: .queued
                )
            )
            completedCount = max(0, completedCount - 1)
            addPersistedTrack(id)
            enqueueBackgroundTrack(track, replacingExisting: false)
            return
        }
        requeueRequests[id] = track
        addPersistedTrack(id)
        setProgress(
            RemoteDownloadProgress(
                id: current.id,
                title: current.title,
                completed: 0,
                total: 0,
                state: .queued
            )
        )
        completedCount = max(0, completedCount - 1)
    }

    func resumePersistedDownloads(from remoteTracks: [RemoteTrackItem], into library: LibraryStore) {
        guard !isDownloading else { return }
        guard !remoteTracks.isEmpty else { return }
        if experimentalBackgroundDownloadsEnabled || !backgroundSession.records().isEmpty {
            resumeBackgroundDownloads(from: remoteTracks, into: library)
            return
        }
        let savedIDs = persistedQueueIDs()
        guard !savedIDs.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: remoteTracks.map { ($0.id, $0) })
        let matchedTracks = savedIDs.compactMap { byID[$0] }
        guard !matchedTracks.isEmpty else { return }
        let candidates = matchedTracks.filter {
            Self.existingDestinationURL(for: $0, in: library.sharedMusicFolderURL) == nil
        }
        guard !candidates.isEmpty else {
            clearPersistedQueue()
            return
        }
        ResonanceDiagnostics.shared.recordDeferred(
            "download.resume",
            details: ["trackCount": String(candidates.count)]
        )
        startDownload(candidates, into: library, replacingExisting: false)
    }

    private func startDownload(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) {
        if experimentalBackgroundDownloadsEnabled {
            startBackgroundDownload(tracks, into: library, replacingExisting: replacingExisting)
            return
        }
        downloadTask?.cancel()
        persistQueue(tracks.map(\.id))
        downloadTask = Task { [weak self] in
            await self?.performDownload(
                tracks,
                into: library,
                replacingExisting: replacingExisting
            )
        }
    }

    private func performDownload(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) async {
        isDownloading = true
        completedCount = 0
        totalCount = tracks.count
        currentCompletedBytes = 0
        currentTotalBytes = 0
        individuallyCancelledTrackIDs = []
        requeueRequests = [:]
        activeTracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.begin",
            details: ["trackCount": String(tracks.count), "replacingExisting": String(replacingExisting)]
        )
        lastMessage = "Preparing \(tracks.count) download\(tracks.count == 1 ? "" : "s")…"
        let initialQueue = tracks.map {
            RemoteDownloadProgress(id: $0.id, title: $0.title, completed: 0, total: 0, state: .queued)
        }
        itemProgress = Dictionary(uniqueKeysWithValues: initialQueue.map { ($0.id, $0) })
        downloadQueue = initialQueue
        defer {
            isDownloading = false
            currentTitle = ""
            currentCompletedBytes = 0
            currentTotalBytes = 0
            activeWorker = nil
            activeTrackID = nil
            requeueRequests = [:]
            activeTracksByID = [:]
            downloadTask = nil
        }

        var pendingTracks = tracks
        while !pendingTracks.isEmpty || !requeueRequests.isEmpty {
            for (_, track) in requeueRequests where !pendingTracks.contains(where: { $0.id == track.id }) {
                pendingTracks.append(track)
            }
            requeueRequests.removeAll()
            guard !pendingTracks.isEmpty else { continue }
            let track = pendingTracks.removeFirst()
            if individuallyCancelledTrackIDs.contains(track.id) {
                if itemProgress[track.id]?.state != .cancelled {
                    setProgress(
                        RemoteDownloadProgress(
                            id: track.id,
                            title: track.title,
                            completed: 0,
                            total: 0,
                            state: .cancelled
                        )
                    )
                    completedCount += 1
                }
                continue
            }
            if Task.isCancelled {
                break
            }
            currentTitle = track.title
            currentCompletedBytes = 0
            currentTotalBytes = max(0, track.fileSizeBytes)
            activeTrackID = track.id
            do {
                let progressStream = AsyncStream<DownloadByteProgress>.makeStream(
                    bufferingPolicy: .bufferingNewest(1)
                )
                let destinationRoot = library.sharedMusicFolderURL
                let worker = Task.detached(priority: .utility) {
                    defer { progressStream.continuation.finish() }
                    return try await Self.downloadOne(
                        track,
                        into: destinationRoot,
                        replacingExisting: replacingExisting
                    ) { completed, total in
                        progressStream.continuation.yield(DownloadByteProgress(completed: completed, total: total))
                    }
                }
                activeWorker = worker
                await withTaskCancellationHandler(operation: {
                    var lastProgressPublication = Date.distantPast
                    for await progress in progressStream.stream {
                        let now = Date()
                        let isFinal = progress.total > 0 && progress.completed >= progress.total
                        // Keep byte-level progress smooth in the queue without invalidating the
                        // entire streaming catalog on every network callback.
                        guard isFinal || now.timeIntervalSince(lastProgressPublication) >= 0.40 else { continue }
                        lastProgressPublication = now
                        currentCompletedBytes = progress.completed
                        currentTotalBytes = progress.total
                        setProgress(
                            RemoteDownloadProgress(
                                id: track.id,
                                title: track.title,
                                completed: Int(min(Int64(Int.max), progress.completed)),
                                total: Int(min(Int64(Int.max), progress.total)),
                                state: .downloading
                            )
                        )
                    }
                }, onCancel: {
                    worker.cancel()
                })
                let result = try await worker.value
                activeWorker = nil
                activeTrackID = nil
                completedCount += 1
                removeProgress(track.id)
                let artworkData = artworkByTrackID[track.id] ?? artworkByAlbumKey[track.albumKey]
                var embeddedArtwork = false
                if let artworkData {
                    embeddedArtwork = await library.writeArtworkToFile(
                        at: result.destination,
                        from: track.asTrack(artworkData: nil),
                        data: artworkData
                    )
                }
                await library.refreshDownloadedTrack(at: result.destination)
                if let artworkData, !embeddedArtwork {
                    library.applyArtworkToApp(for: track.id, data: artworkData)
                }
                removePersistedTrack(track.id)
                ResonanceDiagnostics.shared.recordDeferred(
                    "download.track.completed",
                    details: ["completedCount": String(completedCount), "totalCount": String(totalCount)]
                )
            } catch is CancellationError {
                activeWorker = nil
                activeTrackID = nil
                setProgress(
                    RemoteDownloadProgress(
                        id: track.id,
                        title: track.title,
                        completed: Int(min(Int64(Int.max), currentCompletedBytes)),
                        total: Int(min(Int64(Int.max), currentTotalBytes)),
                        state: .cancelled
                    )
                )
                completedCount += 1
                removePersistedTrack(track.id)
                if Task.isCancelled { break }
                continue
            } catch {
                activeWorker = nil
                activeTrackID = nil
                completedCount += 1
                setProgress(
                    RemoteDownloadProgress(
                        id: track.id,
                        title: track.title,
                        completed: 0,
                        total: 0,
                        state: .failed
                    )
                )
                lastMessage = "Download failed: \(error.localizedDescription)"
            }
        }

        let succeeded = completedCount - itemProgress.values.filter { $0.state == .failed || $0.state == .cancelled }.count
        if Task.isCancelled || itemProgress.values.contains(where: { $0.state == .cancelled }) {
            lastMessage = "Download cancelled after \(succeeded) track\(succeeded == 1 ? "" : "s")"
        } else {
            lastMessage = succeeded == tracks.count
            ? "Downloaded \(succeeded) track\(succeeded == 1 ? "" : "s") to the local library"
            : "Downloaded \(succeeded) of \(tracks.count) tracks; review failed items"
        }
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.end",
            details: ["succeeded": String(succeeded), "totalCount": String(tracks.count), "cancelled": String(Task.isCancelled)]
        )
    }

    private var experimentalBackgroundDownloadsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.experimentalBackgroundDownloadsKey)
    }

    private func startBackgroundDownload(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) {
        prepareBackgroundBatch(tracks, into: library, replacingExisting: replacingExisting)
        lastMessage = "Starting background download…"
        for track in tracks {
            enqueueBackgroundTrack(track, replacingExisting: replacingExisting)
        }
        finishBackgroundBatchIfNeeded()
    }

    private func prepareBackgroundBatch(
        _ tracks: [RemoteTrackItem],
        into library: LibraryStore,
        replacingExisting: Bool
    ) {
        isDownloading = true
        completedCount = 0
        totalCount = tracks.count
        currentCompletedBytes = 0
        currentTotalBytes = 0
        currentTitle = ""
        individuallyCancelledTrackIDs = []
        requeueRequests = [:]
        activeTracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        pendingLibrary = library
        backgroundTaskIdentifiers.removeAll()
        backgroundReplacingExisting = Dictionary(
            uniqueKeysWithValues: tracks.map { ($0.id, replacingExisting) }
        )
        backgroundFinalizing.removeAll()
        let initialQueue = tracks.map {
            RemoteDownloadProgress(id: $0.id, title: $0.title, completed: 0, total: 0, state: .queued)
        }
        itemProgress = Dictionary(uniqueKeysWithValues: initialQueue.map { ($0.id, $0) })
        downloadQueue = initialQueue
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.begin",
            details: [
                "trackCount": String(tracks.count),
                "replacingExisting": String(replacingExisting),
                "background": "true"
            ]
        )
    }

    private func enqueueBackgroundTrack(_ track: RemoteTrackItem, replacingExisting: Bool) {
        guard let taskIdentifier = backgroundSession.enqueue(
            trackID: track.id,
            url: track.streamURL,
            replacingExisting: replacingExisting
        ) else {
            completedCount += 1
            setProgress(
                RemoteDownloadProgress(
                    id: track.id,
                    title: track.title,
                    completed: 0,
                    total: 0,
                    state: .failed
                )
            )
            removePersistedTrack(track.id)
            lastMessage = "A background download URL was invalid"
            return
        }
        backgroundTaskIdentifiers[track.id] = taskIdentifier
        backgroundTrackIDsByTask[taskIdentifier] = track.id
        backgroundReplacingExisting[track.id] = replacingExisting
    }

    private func resumeBackgroundDownloads(from remoteTracks: [RemoteTrackItem], into library: LibraryStore) {
        let savedIDs = persistedQueueIDs()
        let records = backgroundSession.records()
        let orderedIDs = savedIDs + records.map(\.trackID).filter { !savedIDs.contains($0) }
        guard !orderedIDs.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: remoteTracks.map { ($0.id, $0) })
        let matchedTracks = orderedIDs.compactMap { byID[$0] }
        guard !matchedTracks.isEmpty else { return }
        let recordIDs = Set(records.map(\.trackID))
        let candidates = matchedTracks.filter {
            recordIDs.contains($0.id)
                || Self.existingDestinationURL(for: $0, in: library.sharedMusicFolderURL) == nil
        }
        guard !candidates.isEmpty else {
            clearPersistedQueue()
            return
        }
        persistQueue(candidates.map(\.id))
        ResonanceDiagnostics.shared.recordDeferred(
            "download.resume",
            details: ["trackCount": String(candidates.count), "background": "true"]
        )
        prepareBackgroundBatch(candidates, into: library, replacingExisting: false)
        backgroundSession.activeTaskSnapshots { [weak self] snapshots in
            let activeIDs = Set(snapshots.map(\.taskIdentifier))
            Task { @MainActor [weak self] in
                self?.continueBackgroundResume(
                    candidates: candidates,
                    records: records,
                    activeTaskIdentifiers: activeIDs
                )
            }
        }
    }

    private func continueBackgroundResume(
        candidates: [RemoteTrackItem],
        records: [RemoteBackgroundDownloadRecord],
        activeTaskIdentifiers: Set<Int>
    ) {
        let tracksByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        var recordsByTrackID: [UUID: RemoteBackgroundDownloadRecord] = [:]
        for record in records where tracksByID[record.trackID] != nil {
            recordsByTrackID[record.trackID] = record
        }

        for track in candidates {
            if let record = recordsByTrackID[track.id] {
                backgroundReplacingExisting[track.id] = record.replacingExisting
                backgroundTrackIDsByTask[record.taskIdentifier] = track.id
                backgroundTaskIdentifiers[track.id] = record.taskIdentifier
                if let inboxFileName = record.inboxFileName {
                    beginFinalizingBackgroundTrack(
                        track,
                        taskIdentifier: record.taskIdentifier,
                        inboxURL: backgroundSession.urlForInboxFile(named: inboxFileName)
                    )
                } else if activeTaskIdentifiers.contains(record.taskIdentifier) {
                    setProgress(
                        RemoteDownloadProgress(
                            id: track.id,
                            title: track.title,
                            completed: 0,
                            total: Int(min(Int64(Int.max), max(0, track.fileSizeBytes))),
                            state: .downloading
                        )
                    )
                } else {
                    backgroundSession.acknowledge(taskIdentifier: record.taskIdentifier)
                    backgroundTrackIDsByTask.removeValue(forKey: record.taskIdentifier)
                    enqueueBackgroundTrack(track, replacingExisting: record.replacingExisting)
                }
            } else {
                enqueueBackgroundTrack(track, replacingExisting: false)
            }
        }
        lastMessage = "Downloading in the background…"
        finishBackgroundBatchIfNeeded()
    }

    private func handleBackgroundProgress(_ event: RemoteBackgroundNotification) {
        guard activeTracksByID[event.trackID] != nil else { return }
        if let currentTask = backgroundTaskIdentifiers[event.trackID], currentTask != event.taskIdentifier { return }
        currentTitle = activeTracksByID[event.trackID]?.title ?? ""
        currentCompletedBytes = event.completed
        currentTotalBytes = event.total
        setProgress(
            RemoteDownloadProgress(
                id: event.trackID,
                title: activeTracksByID[event.trackID]?.title ?? "Downloading",
                completed: Int(min(Int64(Int.max), max(0, event.completed))),
                total: Int(min(Int64(Int.max), max(0, event.total))),
                state: .downloading
            )
        )
    }

    private func handleBackgroundFinished(_ event: RemoteBackgroundNotification) {
        guard let fileName = event.inboxFileName,
              let track = activeTracksByID[event.trackID] else { return }
        guard backgroundTaskIdentifiers[event.trackID] == event.taskIdentifier else {
            backgroundSession.acknowledge(taskIdentifier: event.taskIdentifier)
            backgroundSession.removeInboxFile(named: fileName)
            backgroundTrackIDsByTask.removeValue(forKey: event.taskIdentifier)
            return
        }
        beginFinalizingBackgroundTrack(
            track,
            taskIdentifier: event.taskIdentifier,
            inboxURL: backgroundSession.urlForInboxFile(named: fileName)
        )
    }

    private func beginFinalizingBackgroundTrack(
        _ track: RemoteTrackItem,
        taskIdentifier: Int,
        inboxURL: URL
    ) {
        guard !backgroundFinalizing.contains(track.id) else { return }
        backgroundFinalizing.insert(track.id)
        Task { @MainActor [weak self] in
            await self?.finalizeBackgroundTrack(
                track,
                taskIdentifier: taskIdentifier,
                inboxURL: inboxURL
            )
        }
    }

    private func finalizeBackgroundTrack(
        _ track: RemoteTrackItem,
        taskIdentifier: Int,
        inboxURL: URL
    ) async {
        guard let library = pendingLibrary else { return }
        let replacingExisting = backgroundReplacingExisting[track.id] ?? false
        let destination = Self.destinationURL(
            for: track,
            in: library.sharedMusicFolderURL,
            extensionName: inboxURL.pathExtension
        )
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: inboxURL.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount > 0 else { throw RemoteDownloadError.emptyResponse }
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            var skipped = false
            if FileManager.default.fileExists(atPath: destination.path) {
                if replacingExisting {
                    try FileManager.default.removeItem(at: destination)
                } else {
                    skipped = true
                }
            }
            if skipped {
                try? FileManager.default.removeItem(at: inboxURL)
            } else {
                try FileManager.default.moveItem(at: inboxURL, to: destination)
            }
            backgroundSession.acknowledge(taskIdentifier: taskIdentifier)
            backgroundSession.removeInboxFile(named: inboxURL.lastPathComponent)
            let artworkData = artworkByTrackID[track.id] ?? artworkByAlbumKey[track.albumKey]
            var embeddedArtwork = false
            if let artworkData {
                embeddedArtwork = await library.writeArtworkToFile(
                    at: destination,
                    from: track.asTrack(artworkData: nil),
                    data: artworkData
                )
            }
            await library.refreshDownloadedTrack(at: destination)
            if let artworkData, !embeddedArtwork {
                library.applyArtworkToApp(for: track.id, data: artworkData)
            }
            removePersistedTrack(track.id)
            completedCount += 1
            removeProgress(track.id)
            ResonanceDiagnostics.shared.recordDeferred(
                "download.track.completed",
                details: [
                    "completedCount": String(completedCount),
                    "totalCount": String(totalCount),
                    "background": "true",
                    "skipped": String(skipped)
                ]
            )
        } catch {
            backgroundSession.acknowledge(taskIdentifier: taskIdentifier)
            backgroundSession.removeInboxFile(named: inboxURL.lastPathComponent)
            markBackgroundFailure(track.id)
        }
        backgroundFinalizing.remove(track.id)
        backgroundTaskIdentifiers.removeValue(forKey: track.id)
        backgroundTrackIDsByTask.removeValue(forKey: taskIdentifier)
        finishBackgroundBatchIfNeeded()
    }

    private func handleBackgroundFailure(_ event: RemoteBackgroundNotification) {
        if let currentTask = backgroundTaskIdentifiers[event.trackID], currentTask != event.taskIdentifier {
            backgroundSession.acknowledge(taskIdentifier: event.taskIdentifier)
            backgroundTrackIDsByTask.removeValue(forKey: event.taskIdentifier)
            return
        }
        backgroundSession.acknowledge(taskIdentifier: event.taskIdentifier)
        backgroundTrackIDsByTask.removeValue(forKey: event.taskIdentifier)
        backgroundTaskIdentifiers.removeValue(forKey: event.trackID)
        if individuallyCancelledTrackIDs.contains(event.trackID) {
            finishBackgroundBatchIfNeeded()
            return
        }
        markBackgroundFailure(event.trackID)
        finishBackgroundBatchIfNeeded()
    }

    private func markBackgroundFailure(_ id: UUID) {
        guard let current = itemProgress[id], current.state != .failed,
              current.state != .cancelled else { return }
        completedCount += 1
        setProgress(
            RemoteDownloadProgress(
                id: current.id,
                title: current.title,
                completed: current.completed,
                total: current.total,
                state: .failed
            )
        )
        lastMessage = "A background download failed; it can be resumed later"
    }

    private func finishBackgroundBatchIfNeeded() {
        guard isDownloading, completedCount >= totalCount else { return }
        let failed = itemProgress.values.filter { $0.state == .failed }.count
        let cancelled = itemProgress.values.filter { $0.state == .cancelled }.count
        let succeeded = max(0, totalCount - failed - cancelled)
        let message: String
        if cancelled > 0 && failed == 0 {
            message = "Download cancelled after \(succeeded) track\(succeeded == 1 ? "" : "s")"
        } else if failed == 0 {
            message = "Downloaded \(succeeded) track\(succeeded == 1 ? "" : "s") to the local library"
        } else {
            message = "Downloaded \(succeeded) of \(totalCount) tracks; review failed items"
        }
        finishBackgroundBatch(message: message)
    }

    private func finishBackgroundBatch(message: String) {
        guard isDownloading else { return }
        isDownloading = false
        currentTitle = ""
        currentCompletedBytes = 0
        currentTotalBytes = 0
        activeTrackID = nil
        activeWorker = nil
        downloadTask = nil
        requeueRequests = [:]
        activeTracksByID = [:]
        pendingLibrary = nil
        backgroundTaskIdentifiers.removeAll()
        backgroundReplacingExisting.removeAll()
        backgroundFinalizing.removeAll()
        lastMessage = message
        ResonanceDiagnostics.shared.recordDeferred(
            "download.batch.end",
            details: ["succeeded": String(max(0, totalCount - itemProgress.values.filter { $0.state == .failed || $0.state == .cancelled }.count)), "totalCount": String(totalCount), "background": "true"]
        )
    }

    private func persistedQueueIDs() -> [UUID] {
        (UserDefaults.standard.array(forKey: Self.persistedQueueIDsKey) as? [String] ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    private func persistQueue(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: Self.persistedQueueIDsKey)
    }

    private func addPersistedTrack(_ id: UUID) {
        var ids = persistedQueueIDs()
        if !ids.contains(id) { ids.append(id) }
        persistQueue(ids)
    }

    private func removePersistedTrack(_ id: UUID) {
        persistQueue(persistedQueueIDs().filter { $0 != id })
    }

    private func clearPersistedQueue() {
        UserDefaults.standard.removeObject(forKey: Self.persistedQueueIDsKey)
    }

    private struct DownloadByteProgress: Sendable {
        let completed: Int64
        let total: Int64
    }

    private func setProgress(_ progress: RemoteDownloadProgress) {
        itemProgress[progress.id] = progress
        if let index = downloadQueue.firstIndex(where: { $0.id == progress.id }) {
            let previousState = downloadQueue[index].state
            downloadQueue[index] = progress
            if previousState != progress.state { prioritizeDownloadQueue() }
        } else {
            downloadQueue.append(progress)
            prioritizeDownloadQueue()
        }
    }

    private func removeProgress(_ id: UUID) {
        itemProgress.removeValue(forKey: id)
        downloadQueue.removeAll { $0.id == id }
    }

    private func prioritizeDownloadQueue() {
        downloadQueue.sort { lhs, rhs in
            let lhsActive = lhs.state == .downloading
            let rhsActive = rhs.state == .downloading
            if lhsActive != rhsActive { return lhsActive }
            let lhsQueued = lhs.state == .queued
            let rhsQueued = rhs.state == .queued
            if lhsQueued != rhsQueued { return lhsQueued }
            return false
        }
    }

    private nonisolated static func downloadOne(
        _ track: RemoteTrackItem,
        into root: URL,
        replacingExisting: Bool,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws -> DownloadResult {
        guard let scheme = track.streamURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RemoteDownloadError.invalidURL
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: track.streamURL)
        guard let http = response as? HTTPURLResponse else { throw RemoteDownloadError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RemoteDownloadError.httpStatus(http.statusCode) }

        let extensionName = Self.fileExtension(for: response, fallback: track.streamURL.pathExtension)
        let destination = Self.destinationURL(for: track, in: root, extensionName: extensionName)
        let directory = destination.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(".resonance-\(UUID().uuidString).part")
        let expectedBytes = max(0, max(response.expectedContentLength, track.fileSizeBytes))
        var completedBytes: Int64 = 0

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: temporaryURL)
            defer { try? handle.close() }

            var buffer = Data()
            buffer.reserveCapacity(256 * 1024)
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 256 * 1024 {
                    try handle.write(contentsOf: buffer)
                    completedBytes += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    progress(completedBytes, expectedBytes)
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                completedBytes += Int64(buffer.count)
                progress(completedBytes, expectedBytes)
            }
            guard completedBytes > 0 else { throw RemoteDownloadError.emptyResponse }
            try handle.close()

            if FileManager.default.fileExists(atPath: destination.path) {
                guard replacingExisting else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    return DownloadResult(bytes: completedBytes, skipped: true, destination: destination)
                }
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return DownloadResult(bytes: completedBytes, skipped: false, destination: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private nonisolated static func destinationURL(
        for track: RemoteTrackItem,
        in root: URL,
        extensionName: String? = nil
    ) -> URL {
        let artistFolder = Self.safeComponent(track.albumArtist.isEmpty ? track.artist : track.albumArtist)
        let albumFolder = Self.safeComponent(track.album.isEmpty ? "Unknown Album" : track.album)
        let trackNumber = track.trackNumber > 0 ? String(format: "%02d", track.trackNumber) : "00"
        let discPrefix = track.discNumber > 1 ? "D\(track.discNumber)-" : ""
        let ext = extensionName ?? Self.fileExtension(for: nil, fallback: track.streamURL.pathExtension)
        let fileName = Self.safeComponent("\(discPrefix)\(trackNumber) - \(track.title)") + ".\(ext)"
        return root
            .appendingPathComponent(artistFolder, isDirectory: true)
            .appendingPathComponent(albumFolder, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private nonisolated static func existingDestinationURL(
        for track: RemoteTrackItem,
        in root: URL
    ) -> URL? {
        var extensions = MetadataReader.supportedExtensions
        let streamExtension = track.streamURL.pathExtension.lowercased()
        if !streamExtension.isEmpty { extensions.insert(streamExtension) }
        for extensionName in extensions {
            let candidate = destinationURL(for: track, in: root, extensionName: extensionName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private nonisolated static func fileExtension(for response: URLResponse?, fallback: String) -> String {
        let mime = response?.mimeType?.lowercased() ?? ""
        let mapped: String
        switch mime {
        case "audio/flac", "audio/x-flac": mapped = "flac"
        case "audio/mpeg", "audio/mp3": mapped = "mp3"
        case "audio/mp4", "audio/x-m4a": mapped = "m4a"
        case "audio/aac": mapped = "aac"
        case "audio/wav", "audio/x-wav": mapped = "wav"
        case "audio/aiff", "audio/x-aiff": mapped = "aiff"
        case "audio/ogg", "audio/opus": mapped = "ogg"
        default: mapped = ""
        }
        let candidate = mapped.isEmpty ? fallback.lowercased() : mapped
        return MetadataReader.supportedExtensions.contains(candidate) ? candidate : "mp3"
    }

    private nonisolated static func safeComponent(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r")
        let cleaned = value.unicodeScalars.map { forbidden.contains($0) ? "_" : String($0) }.joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown" : String(trimmed.prefix(180))
    }
}
