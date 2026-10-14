import Foundation

/// Stores one course's practice log as one JSON file. See `PracticeLogFile` for the format.
///
/// Mirrors `FileProgressStore`: every operation is a whole read-modify-write inside the actor, writes are
/// atomic, and a file that cannot be decoded (or comes from a newer schema) is never overwritten or
/// deleted by `load` or `append`; only an explicit `erase` removes it. Errors carry no paths and no file
/// content. The app chooses the URL (one file per course).
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FilePracticeLogStore: PracticeLogStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "practice log file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(PracticeLogError) -> PracticeLog {
        try readLog()
    }

    public func append(_ session: PracticeSession) async throws(PracticeLogError) {
        // Reading first means a corrupt or future-schema file throws here instead of being replaced,
        // even for a session that would then be ignored.
        let current = try readLog()
        guard session.countsTowardStreak else { return }
        let data = try PracticeLogFile(log: current.appending(session)).encoded()
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw .writeFailed
        }
    }

    public func erase() async throws(PracticeLogError) {
        // unlink(2) rather than FileManager.removeItem: it removes a file and nothing else, so a
        // misconfigured URL that names a directory fails instead of deleting a tree.
        let result = fileURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return EINVAL }
            return unlink(path) == 0 ? 0 : errno
        }
        guard result == 0 || result == ENOENT else { throw .eraseFailed }
    }

    private func readLog() throws(PracticeLogError) -> PracticeLog {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .empty
        } catch {
            throw .unreadable
        }
        return try PracticeLogFile.decodeLog(from: data)
    }
}
