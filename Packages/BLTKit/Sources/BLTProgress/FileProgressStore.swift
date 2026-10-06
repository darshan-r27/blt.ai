import Foundation

/// Stores progress as one JSON file (DECISIONS 028). See `ProgressFile` for the format.
///
/// Every operation is a whole read-modify-write inside the actor with no suspension point in between,
/// so concurrent `record` calls are serialised and none is lost.
///
/// A file that cannot be decoded is never overwritten or deleted by `load` or `record`; only an explicit
/// `eraseAll` removes it. Errors carry no paths and no file content.
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FileProgressStore: ProgressStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "progress file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(ProgressStoreError) -> ProgressSnapshot {
        try readSnapshot()
    }

    public func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {
        precondition(review.itemID == attempt.itemID, "review and attempt must be for the same item")
        // Reading first means a corrupt or future-schema file throws here instead of being replaced.
        let next = try readSnapshot().recording(attempt, updating: review)
        let data = try ProgressFile(snapshot: next).encoded()
        do {
            // Default protection on the directory; the file itself gets complete protection below.
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw .writeFailed
        }
    }

    public func eraseAll() async throws(ProgressStoreError) {
        // unlink(2) rather than FileManager.removeItem: it removes a file and nothing else, so a
        // misconfigured URL that names a directory fails instead of deleting a tree.
        let result = fileURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return EINVAL }
            return unlink(path) == 0 ? 0 : errno
        }
        guard result == 0 || result == ENOENT else { throw .eraseFailed }
    }

    private func readSnapshot() throws(ProgressStoreError) -> ProgressSnapshot {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .empty
        } catch {
            throw .unreadable
        }
        return try ProgressFile.decodeSnapshot(from: data)
    }
}
