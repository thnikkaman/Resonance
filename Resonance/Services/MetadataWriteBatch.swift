import Foundation

struct MetadataWriteRequest: Sendable {
    let id: UUID
    let url: URL
    let values: MetadataTagValues
    let artworkData: Data?
    let replaceArtwork: Bool
}

struct MetadataWriteBatchResult: Sendable {
    let successfulIDs: Set<UUID>
    let failures: [String]
}

enum MetadataWriteBatch {
    /// Writes requests sequentially, preserving the existing editor behavior
    /// while giving track, album, and artist workflows one error boundary.
    static func write(_ requests: [MetadataWriteRequest]) async -> MetadataWriteBatchResult {
        var successfulIDs = Set<UUID>()
        var failures: [String] = []

        ResonanceDiagnostics.shared.recordDeferredAlways(
            "metadata.write.batch.begin",
            details: ["requestCount": String(requests.count)]
        )

        for request in requests {
            let requestKey = String(request.id.uuidString.prefix(8))
            let extensionName = request.url.pathExtension.lowercased()
            ResonanceDiagnostics.shared.recordDeferredAlways(
                "metadata.write.request.begin",
                details: [
                    "request": requestKey,
                    "extension": extensionName,
                    "fileExists": String(FileManager.default.fileExists(atPath: request.url.path)),
                    "titleLength": String(request.values.title.utf8.count),
                    "artistLength": String(request.values.artist.utf8.count),
                    "albumArtistLength": String(request.values.albumArtist.utf8.count),
                    "albumLength": String(request.values.album.utf8.count),
                    "trackNumber": String(request.values.trackNumber),
                    "discNumber": String(request.values.discNumber),
                    "releaseYear": String(request.values.releaseYear),
                    "artworkBytes": String(request.artworkData?.count ?? 0),
                    "replaceArtwork": String(request.replaceArtwork)
                ]
            )
            do {
                try await Task.detached(priority: .utility) {
                    try ExternalFileCoordinator.write(at: request.url) { coordinatedURL in
                        try MetadataTagWriter.write(
                            to: coordinatedURL,
                            values: request.values,
                            artworkData: request.artworkData,
                            replaceArtwork: request.replaceArtwork
                        )
                    }
                }.value
                successfulIDs.insert(request.id)
                ResonanceDiagnostics.shared.recordDeferredAlways(
                    "metadata.write.request.success",
                    details: [
                        "request": requestKey,
                        "extension": extensionName,
                        "fileBytesAfter": String(fileSize(at: request.url) ?? 0)
                    ]
                )
            } catch {
                ResonanceDiagnostics.shared.recordDeferredAlways(
                    "metadata.write.request.failure",
                    details: [
                        "request": requestKey,
                        "extension": extensionName,
                        "errorType": String(describing: type(of: error)),
                        "error": error.localizedDescription
                    ]
                )
                failures.append(error.localizedDescription)
            }
        }

        ResonanceDiagnostics.shared.recordDeferredAlways(
            "metadata.write.batch.end",
            details: [
                "requestCount": String(requests.count),
                "successCount": String(successfulIDs.count),
                "failureCount": String(failures.count)
            ]
        )

        return MetadataWriteBatchResult(successfulIDs: successfulIDs, failures: failures)
    }

    private static func fileSize(at url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }
}
