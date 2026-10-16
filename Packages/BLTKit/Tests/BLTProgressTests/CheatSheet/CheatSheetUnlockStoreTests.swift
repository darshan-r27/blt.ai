import BLTProgress
import Foundation
import Testing

/// `FileCheatSheetUnlockStore` and `InMemoryCheatSheetUnlockStore`: the same contract, plus the file's
/// failure modes. Topic ids are fake (`zz-`).
struct CheatSheetUnlockStoreTests {
    private typealias Support = PracticeTestSupport

    private func withFileStore(_ body: (FileCheatSheetUnlockStore, URL) async throws -> Void) async throws {
        try await Support.withScratchDirectory { directory in
            let fileURL = directory
                .appendingPathComponent("courses", isDirectory: true)
                .appendingPathComponent("zz-language", isDirectory: true)
                .appendingPathComponent("cheatsheets.json")
            try await body(FileCheatSheetUnlockStore(fileURL: fileURL), fileURL)
        }
    }

    private func checkContract(_ store: any CheatSheetUnlockStore) async throws {
        #expect(try await store.load().isEmpty)

        try await store.add(["zz-b", "zz-a"])
        #expect(try await store.load() == ["zz-a", "zz-b"])

        // The same topic twice, and an empty add, change nothing.
        try await store.add(["zz-a"])
        try await store.add([])
        #expect(try await store.load() == ["zz-a", "zz-b"])

        try await store.add(["zz-c", "zz-a"])
        #expect(try await store.load() == ["zz-a", "zz-b", "zz-c"])

        try await store.erase()
        #expect(try await store.load().isEmpty)
        try await store.erase()
        try await store.add(["zz-a"])
        #expect(try await store.load() == ["zz-a"])
    }

    @Test func fileStoreMeetsTheContract() async throws {
        try await withFileStore { store, _ in try await checkContract(store) }
    }

    @Test func inMemoryStoreMeetsTheContract() async throws {
        try await checkContract(InMemoryCheatSheetUnlockStore())
    }

    @Test func inMemoryStoreStartsWithItsInitialTopics() async throws {
        let store = InMemoryCheatSheetUnlockStore(initial: ["zz-a"])
        #expect(try await store.load() == ["zz-a"])
    }

    @Test func fileStoreReopensWithWhatWasWritten() async throws {
        try await withFileStore { store, fileURL in
            try await store.add(["zz-a", "zz-b"])
            let reopened = FileCheatSheetUnlockStore(fileURL: fileURL)
            #expect(try await reopened.load() == ["zz-a", "zz-b"])
        }
    }

    @Test func fileHasASchemaVersionAndSortedIDs() async throws {
        try await withFileStore { store, fileURL in
            try await store.add(["zz-b", "zz-a"])
            let text = String(bytes: try Support.bytes(of: fileURL), encoding: .utf8)
            #expect(text == "{\"schemaVersion\":1,\"topicIDs\":[\"zz-a\",\"zz-b\"]}")
        }
    }

    @Test func addingTheSameTopicTwiceLeavesTheFileUnchanged() async throws {
        try await withFileStore { store, fileURL in
            try await store.add(["zz-a"])
            let before = try Support.bytes(of: fileURL)
            try await store.add(["zz-a"])
            #expect(try Support.bytes(of: fileURL) == before)
        }
    }

    @Test func addingNothingCreatesNoFile() async throws {
        try await withFileStore { store, fileURL in
            try await store.add([])
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func damagedFileIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let damaged = Data("{ not json".utf8)
            try damaged.write(to: fileURL)

            await #expect(throws: CheatSheetUnlockError.corrupt) { try await store.load() }
            await #expect(throws: CheatSheetUnlockError.corrupt) { try await store.add(["zz-a"]) }
            // An add that would change nothing still reports the damage.
            await #expect(throws: CheatSheetUnlockError.corrupt) { try await store.add([]) }
            #expect(try Support.bytes(of: fileURL) == damaged)
        }
    }

    @Test func wrongShapeIsCorruptNotEmpty() async throws {
        try await withFileStore { store, fileURL in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try Data("{\"schemaVersion\":1,\"topicIDs\":[1,2]}".utf8).write(to: fileURL)
            await #expect(throws: CheatSheetUnlockError.corrupt) { try await store.load() }
        }
    }

    @Test func newerSchemaIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let future = Data("{\"schemaVersion\":99,\"somethingNew\":true}".utf8)
            try future.write(to: fileURL)

            await #expect(throws: CheatSheetUnlockError.unsupportedSchemaVersion(99)) { try await store.load() }
            await #expect(throws: CheatSheetUnlockError.unsupportedSchemaVersion(99)) {
                try await store.add(["zz-a"])
            }
            #expect(try Support.bytes(of: fileURL) == future)
        }
    }

    @Test func eraseRemovesADamagedFile() async throws {
        try await withFileStore { store, fileURL in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try Data("{ not json".utf8).write(to: fileURL)
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            #expect(try await store.load().isEmpty)
        }
    }

    @Test func eraseDoesNotRemoveADirectory() async throws {
        try await Support.withScratchDirectory { directory in
            let store = FileCheatSheetUnlockStore(fileURL: directory)
            await #expect(throws: CheatSheetUnlockError.eraseFailed) { try await store.erase() }
            #expect(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func concurrentAddsAreAllKept() async throws {
        try await withFileStore { store, _ in
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<10 {
                    group.addTask { try? await store.add(["zz-\(index)"]) }
                }
            }
            let topics = try await store.load()
            #expect(topics.count == 10)
        }
    }
}
