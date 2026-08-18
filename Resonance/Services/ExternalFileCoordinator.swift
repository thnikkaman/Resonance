import Foundation

/// Coordinates reads and writes through Files, iCloud Drive, and other file
/// providers. The selected folder remains security-scoped; coordination makes
/// the provider and other apps arbitrate access to the same item.
enum ExternalFileCoordinator {
    private enum CoordinationError: LocalizedError {
        case accessorWasNotInvoked

        var errorDescription: String? {
            "The external file provider did not grant a coordinated access operation."
        }
    }

    static func read<T>(
        at url: URL,
        options: NSFileCoordinator.ReadingOptions = [],
        _ accessor: (URL) throws -> T
    ) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(
            readingItemAt: url,
            options: options,
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw CoordinationError.accessorWasNotInvoked
        }
        return try result.get()
    }

    static func write<T>(
        at url: URL,
        options: NSFileCoordinator.WritingOptions = [],
        _ accessor: (URL) throws -> T
    ) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(
            writingItemAt: url,
            options: options,
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw CoordinationError.accessorWasNotInvoked
        }
        return try result.get()
    }

    /// Moves a completed download into a coordinated folder. Returns true
    /// when an existing destination was kept and the source should be removed
    /// by the caller.
    @discardableResult
    static func moveItem(
        from sourceURL: URL,
        to destinationURL: URL,
        replacingExisting: Bool
    ) throws -> Bool {
        try write(at: destinationURL) { coordinatedDestination in
            try FileManager.default.createDirectory(
                at: coordinatedDestination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: coordinatedDestination.path) {
                guard replacingExisting else { return true }
                try FileManager.default.removeItem(at: coordinatedDestination)
            }
            try FileManager.default.moveItem(at: sourceURL, to: coordinatedDestination)
            return false
        }
    }
}
