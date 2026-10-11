import BLTProgress
import Foundation
import Testing

/// The one-time clean-up of the single-course build's files (DECISIONS 043).
struct LegacyStorageSweepTests {
    /// Runs `body` with a fresh support folder and a second folder beside it for things a link may point at.
    private func withFolders(_ body: (_ support: URL, _ elsewhere: URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "zz-sweep-\(UUID().uuidString)", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let elsewhere = root.appending(path: "elsewhere", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(support, elsewhere)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    private func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    private func seedLegacy(in support: URL) throws {
        try write("zz old progress", to: support.appending(path: "progress.json"))
        try write("zz lesson one", to: support.appending(path: "content/a1.json"))
        try write("zz lesson two", to: support.appending(path: "content/a2.json"))
        try write("zz manifest", to: support.appending(path: "content/manifest.json"))
    }

    @Test func removesTheOldProgressFileAndTheImportedLessonsFolder() throws {
        try withFolders { support, _ in
            try seedLegacy(in: support)

            let report = LegacyStorageSweep(directory: support).run()

            #expect(!exists(support.appending(path: "progress.json")))
            #expect(!exists(support.appending(path: "content")))
            #expect(report.removedProgressFile)
            #expect(report.removedImportedFolder)
            #expect(report.importedEntryCount == 3)
            #expect(report.failedCount == 0)
        }
    }

    @Test func leavesTheProfileTheCoursesFolderAndTheUITestFilesAlone() throws {
        try withFolders { support, _ in
            try seedLegacy(in: support)
            try write("zz profile", to: support.appending(path: "profile.json"))
            try write("zz tamil progress", to: support.appending(path: "courses/tamil/progress.json"))
            try write("zz tamil import", to: support.appending(path: "courses/tamil/content/b1.json"))
            try write("zz telugu progress", to: support.appending(path: "courses/telugu/progress.json"))
            try write("zz ui profile", to: support.appending(path: "uitest-profile.json"))
            try write("zz ui progress", to: support.appending(path: "uitest-progress-tamil.json"))
            try write("zz ui import", to: support.appending(path: "uitest-content-tamil/c1.json"))

            LegacyStorageSweep(directory: support).run()

            let kept = [
                "profile.json",
                "courses/tamil/progress.json",
                "courses/tamil/content/b1.json",
                "courses/telugu/progress.json",
                "uitest-profile.json",
                "uitest-progress-tamil.json",
                "uitest-content-tamil/c1.json"
            ]
            for path in kept {
                #expect(exists(support.appending(path: path)), "\(path) must survive")
            }
            #expect(!exists(support.appending(path: "progress.json")))
            #expect(!exists(support.appending(path: "content")))
        }
    }

    @Test func isSafeWhenNothingExists() throws {
        try withFolders { support, _ in
            let report = LegacyStorageSweep(directory: support).run()
            #expect(report.foundNothing)
            #expect(report.importedEntryCount == 0)
        }
    }

    @Test func isSafeWhenTheSupportFolderItselfDoesNotExist() throws {
        try withFolders { support, _ in
            let missing = support.appending(path: "never-created", directoryHint: .isDirectory)
            let report = LegacyStorageSweep(directory: missing).run()
            #expect(report.foundNothing)
            #expect(!exists(missing))
        }
    }

    @Test func aSecondRunFindsNothing() throws {
        try withFolders { support, _ in
            try seedLegacy(in: support)
            try write("zz profile", to: support.appending(path: "profile.json"))

            let sweep = LegacyStorageSweep(directory: support)
            #expect(!sweep.run().foundNothing)
            let second = sweep.run()

            #expect(second.foundNothing)
            #expect(exists(support.appending(path: "profile.json")))
        }
    }

    @Test func removesOnlyTheOldProgressFileWhenThereAreNoImports() throws {
        try withFolders { support, _ in
            try write("zz old progress", to: support.appending(path: "progress.json"))

            let report = LegacyStorageSweep(directory: support).run()

            #expect(report.removedProgressFile)
            #expect(!report.removedImportedFolder)
            #expect(report.failedCount == 0)
        }
    }

    @Test func aLinkToAFolderIsUnlinkedAndWhatItPointsAtIsKept() throws {
        try withFolders { support, elsewhere in
            let target = elsewhere.appending(path: "precious", directoryHint: .isDirectory)
            try write("zz precious", to: target.appending(path: "keep.json"))
            try FileManager.default.createSymbolicLink(
                at: support.appending(path: "content"),
                withDestinationURL: target
            )

            let report = LegacyStorageSweep(directory: support).run()

            #expect(!exists(support.appending(path: "content")), "the link itself is removed")
            #expect(exists(target.appending(path: "keep.json")), "what it pointed at is not followed")
            #expect(report.removedImportedFolder)
            #expect(report.importedEntryCount == 0, "a link is not opened, so nothing inside it is counted")
        }
    }

    @Test func aLinkToAFileIsUnlinkedAndWhatItPointsAtIsKept() throws {
        try withFolders { support, elsewhere in
            let target = elsewhere.appending(path: "precious.json")
            try write("zz precious", to: target)
            try FileManager.default.createSymbolicLink(
                at: support.appending(path: "progress.json"),
                withDestinationURL: target
            )

            let report = LegacyStorageSweep(directory: support).run()

            #expect(!exists(support.appending(path: "progress.json")))
            #expect(exists(target))
            #expect(report.removedProgressFile)
        }
    }

    @Test func aDanglingLinkIsRemovedToo() throws {
        try withFolders { support, elsewhere in
            try FileManager.default.createSymbolicLink(
                at: support.appending(path: "progress.json"),
                withDestinationURL: elsewhere.appending(path: "does-not-exist.json")
            )

            let report = LegacyStorageSweep(directory: support).run()

            #expect(!exists(support.appending(path: "progress.json")))
            #expect(report.removedProgressFile)
        }
    }
}
