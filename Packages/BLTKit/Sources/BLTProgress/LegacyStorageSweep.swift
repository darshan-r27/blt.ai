import Foundation

/// Removes the files the single-course build left in the app's support folder (DECISIONS 043).
///
/// That build kept `progress.json` and an imported-lessons folder `content/` directly in the support folder.
/// The two-course build keeps them per language under `courses/<language>/` and migrates nothing: the old
/// lesson ids no longer exist, and the owner confirmed on 2026-10-09 that no learner has progress to keep. So
/// the old files are removed once, at launch, rather than left behind as orphans.
///
/// The sweep only ever touches those two names, directly inside `directory`. It leaves `profile.json`,
/// everything under `courses/` and anything else alone. It is idempotent (a second run finds nothing), and it
/// never follows a symbolic link: a link in either place is itself unlinked and what it pointed at is left
/// untouched. A failure to remove something is counted, never thrown, so a launch is never blocked by it.
public struct LegacyStorageSweep: Sendable {
    /// What one run did. Counts only: nothing here names a file, so it is safe to log.
    public struct Report: Sendable, Equatable {
        public let removedProgressFile: Bool
        public let removedImportedFolder: Bool
        /// Entries that were directly inside the removed imported folder (lesson files and the manifest).
        public let importedEntryCount: Int
        /// Paths that were present and could not be removed. They are retried at the next launch.
        public let failedCount: Int

        /// True when the run found and removed nothing and nothing failed.
        public var foundNothing: Bool {
            !removedProgressFile && !removedImportedFolder && failedCount == 0
        }
    }

    public static let legacyProgressFileName = "progress.json"
    public static let legacyImportedFolderName = "content"

    private let directory: URL

    /// `directory` is the support folder that holds the old files (`Application Support/BLT`).
    public init(directory: URL) {
        self.directory = directory
    }

    @discardableResult
    public func run() -> Report {
        var failed = 0
        let progressURL = directory.appending(path: Self.legacyProgressFileName, directoryHint: .notDirectory)
        let importedURL = directory.appending(path: Self.legacyImportedFolderName, directoryHint: .isDirectory)

        let removedProgress = remove(progressURL, failed: &failed)

        // Count before removing. A symbolic link is not opened, so a link counts as zero entries.
        let entryCount = isRealDirectory(importedURL)
            ? ((try? FileManager.default.contentsOfDirectory(atPath: importedURL.path)) ?? []).count
            : 0
        let removedImported = remove(importedURL, failed: &failed)

        return Report(
            removedProgressFile: removedProgress,
            removedImportedFolder: removedImported,
            importedEntryCount: removedImported ? entryCount : 0,
            failedCount: failed
        )
    }

    /// Removes `url` if something is there, including a dangling link. `FileManager.removeItem` unlinks a
    /// symbolic link itself and does not follow it. Returns whether something was removed.
    private func remove(_ url: URL, failed: inout Int) -> Bool {
        guard exists(url) else { return false }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            failed += 1
            return false
        }
    }

    /// `attributesOfItem` describes the link itself rather than its target, so a dangling link still counts.
    private func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    private func isRealDirectory(_ url: URL) -> Bool {
        let type = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
        return type == .typeDirectory
    }
}
