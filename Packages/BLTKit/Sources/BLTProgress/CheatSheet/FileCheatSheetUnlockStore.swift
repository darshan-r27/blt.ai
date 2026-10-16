import Foundation

/// Stores one course's unlocked cheat-sheet topics as one JSON file. See `CheatSheetUnlockFile` for the
/// format.
///
/// Mirrors `FilePracticeLogStore`: every operation is a whole read-modify-write inside the actor, writes are
/// atomic, and a file that cannot be decoded (or comes from a newer schema) is never overwritten or
/// deleted by `load` or `add`; only an explicit `erase` removes it. Errors carry no paths and no file
/// content. The app chooses the URL (`courses/<language>/cheatsheets.json`).
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FileCheatSheetUnlockStore: CheatSheetUnlockStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "cheat sheet unlock file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(CheatSheetUnlockError) -> Set<String> {
        try readTopicIDs()
    }

    public func add(_ topicIDs: Set<String>) async throws(CheatSheetUnlockError) {
        // Reading first means a corrupt or future-schema file throws here instead of being replaced,
        // even when nothing new would be written.
        let current = try readTopicIDs()
        let merged = current.union(topicIDs)
        guard merged != current else { return }
        let data = try CheatSheetUnlockFile(topicIDs: merged).encoded()
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

    public func erase() async throws(CheatSheetUnlockError) {
        // unlink(2) rather than FileManager.removeItem: it removes a file and nothing else, so a
        // misconfigured URL that names a directory fails instead of deleting a tree.
        let result = fileURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return EINVAL }
            return unlink(path) == 0 ? 0 : errno
        }
        guard result == 0 || result == ENOENT else { throw .eraseFailed }
    }

    private func readTopicIDs() throws(CheatSheetUnlockError) -> Set<String> {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        } catch {
            throw .unreadable
        }
        return try CheatSheetUnlockFile.decodeTopicIDs(from: data)
    }
}
