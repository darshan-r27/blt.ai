import Foundation

/// Stores exam attempts as one JSON file (DECISIONS 041, 043). See `ExamResultFile` for the format.
///
/// The caller passes the file URL (`Application Support/BLT/courses/<language>/exam.json`), so the store
/// knows no language. Mirrors `FileProfileStore`: a file that cannot be decoded, or that comes from a newer
/// schema, is never overwritten or deleted by `load` or `append`; only an explicit `erase` removes it.
/// Errors carry no paths and no file content.
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FileExamResultStore: ExamResultStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "exam result file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(ExamResultStoreError) -> [ExamAttempt] {
        try readAttempts()
    }

    public func append(_ attempt: ExamAttempt) async throws(ExamResultStoreError) {
        // Reading first means a corrupt or future-schema file throws here instead of being replaced.
        let updated = ExamHistory.appending(attempt, to: try readAttempts())
        let data = try ExamResultFile(attempts: updated).encoded()
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

    public func erase() async throws(ExamResultStoreError) {
        // unlink(2) rather than FileManager.removeItem: it removes a file and nothing else, so a
        // misconfigured URL that names a directory fails instead of deleting a tree.
        let result = fileURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return EINVAL }
            return unlink(path) == 0 ? 0 : errno
        }
        guard result == 0 || result == ENOENT else { throw .eraseFailed }
    }

    private func readAttempts() throws(ExamResultStoreError) -> [ExamAttempt] {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        } catch {
            throw .unreadable
        }
        return try ExamResultFile.decodeAttempts(from: data)
    }
}
