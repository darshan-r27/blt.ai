import BLTProgress
import Foundation
import Testing

/// `FilePracticeLogStore` and `InMemoryPracticeLogStore`: the same contract, plus the file's failure modes.
struct PracticeLogStoreTests {
    private typealias Support = PracticeTestSupport

    private func withFileStore(_ body: (FilePracticeLogStore, URL) async throws -> Void) async throws {
        try await Support.withScratchDirectory { directory in
            let fileURL = directory.appendingPathComponent("practice.json")
            try await body(FilePracticeLogStore(fileURL: fileURL), fileURL)
        }
    }

    private func checkContract(_ store: any PracticeLogStore) async throws {
        #expect(try await store.load() == .empty)

        let first = PracticeSession(finishedAt: Date(timeIntervalSince1970: 1_760_000_000.25), answered: 10)
        let second = Support.session(Support.date(2, 9), answered: 4)
        try await store.append(second)
        try await store.append(first)
        // Time order, and the sub-second value survives.
        #expect(try await store.load().sessions == [first, second])

        try await store.append(Support.session(Support.date(3, 9), answered: 0))
        #expect(try await store.load().sessions == [first, second])

        try await store.erase()
        #expect(try await store.load() == .empty)
        try await store.erase()
        try await store.append(first)
        #expect(try await store.load().sessions == [first])
    }

    @Test func fileStoreMeetsTheContract() async throws {
        try await withFileStore { store, _ in try await checkContract(store) }
    }

    @Test func inMemoryStoreMeetsTheContract() async throws {
        try await checkContract(InMemoryPracticeLogStore())
    }

    @Test func fileStoreReopensWithWhatWasWritten() async throws {
        try await withFileStore { store, fileURL in
            try await store.append(Support.session(Support.date(1, 9)))
            let reopened = FilePracticeLogStore(fileURL: fileURL)
            #expect(try await reopened.load().sessions == [Support.session(Support.date(1, 9))])
        }
    }

    @Test func fileHasASchemaVersion() async throws {
        try await withFileStore { store, fileURL in
            try await store.append(Support.session(Date(timeIntervalSince1970: 1_760_000_000)))
            let text = String(bytes: try Support.bytes(of: fileURL), encoding: .utf8)
            #expect(text == "{\"schemaVersion\":1,\"sessions\":[{\"answered\":10,\"finishedAt\":1760000000}]}")
        }
    }

    @Test func zeroAnswerSessionCreatesNoFile() async throws {
        try await withFileStore { store, fileURL in
            try await store.append(Support.session(Support.date(1, 9), answered: 0))
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func damagedFileIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            let damaged = Data("{ not json".utf8)
            try damaged.write(to: fileURL)

            await #expect(throws: PracticeLogError.corrupt) { try await store.load() }
            await #expect(throws: PracticeLogError.corrupt) {
                try await store.append(Support.session(Support.date(1, 9)))
            }
            // A session that would be ignored still reports the damage.
            await #expect(throws: PracticeLogError.corrupt) {
                try await store.append(Support.session(Support.date(1, 9), answered: 0))
            }
            #expect(try Support.bytes(of: fileURL) == damaged)
        }
    }

    @Test func wrongShapeIsCorruptNotEmpty() async throws {
        try await withFileStore { store, fileURL in
            try Data("{\"schemaVersion\":1,\"sessions\":[{\"answered\":\"ten\"}]}".utf8).write(to: fileURL)
            await #expect(throws: PracticeLogError.corrupt) { try await store.load() }
        }
    }

    @Test func newerSchemaIsReportedAndNeverOverwritten() async throws {
        try await withFileStore { store, fileURL in
            let future = Data("{\"schemaVersion\":99,\"somethingNew\":true}".utf8)
            try future.write(to: fileURL)

            await #expect(throws: PracticeLogError.unsupportedSchemaVersion(99)) { try await store.load() }
            await #expect(throws: PracticeLogError.unsupportedSchemaVersion(99)) {
                try await store.append(Support.session(Support.date(1, 9)))
            }
            #expect(try Support.bytes(of: fileURL) == future)
        }
    }

    @Test func eraseRemovesADamagedFile() async throws {
        try await withFileStore { store, fileURL in
            try Data("{ not json".utf8).write(to: fileURL)
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            #expect(try await store.load() == .empty)
        }
    }

    @Test func eraseDoesNotRemoveADirectory() async throws {
        try await Support.withScratchDirectory { directory in
            let store = FilePracticeLogStore(fileURL: directory)
            await #expect(throws: PracticeLogError.eraseFailed) { try await store.erase() }
            #expect(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func concurrentAppendsAreAllKept() async throws {
        try await withFileStore { store, _ in
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<10 {
                    group.addTask { try? await store.append(Support.session(Support.date(1, index))) }
                }
            }
            let log = try await store.load()
            #expect(log.sessions.count == 10)
        }
    }
}
