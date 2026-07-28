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

        for request in requests {
            do {
                try await Task.detached(priority: .utility) {
                    try MetadataTagWriter.write(
                        to: request.url,
                        values: request.values,
                        artworkData: request.artworkData,
                        replaceArtwork: request.replaceArtwork
                    )
                }.value
                successfulIDs.insert(request.id)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        return MetadataWriteBatchResult(successfulIDs: successfulIDs, failures: failures)
    }
}
