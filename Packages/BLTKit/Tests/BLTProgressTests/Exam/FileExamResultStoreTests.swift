import BLTProgress
import Foundation
import Testing

struct FileExamResultStoreTests {
    private typealias Contract = ExamResultStoreContract

    /// Runs `body` with a store whose file lives in a fresh scratch directory.
    private func withStore(_ body: (FileExamResultStore, URL) async throws -> Void) async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory.appendingPathComponent("exam.json")
            try await body(FileExamResultStore(fileURL: fileURL), fileURL)
        }
    }

    private func bytes(of fileURL: URL) throws -> Data {
        guard fileURL.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try Data(contentsOf: fileURL)
    }

    private func write(_ json: String, to fileURL: URL) throws {
        try Data(json.utf8).write(to: fileURL)
    }

    // MARK: Shared contract

    @Test func newStoreLoadsEmpty() async throws {
        try await withStore { store, _ in try await Contract.checkNewStoreLoadsEmpty(store) }
    }

    @Test func appendRoundTrips() async throws {
        try await withStore { store, _ in try await Contract.checkAppendRoundTrips(store) }
    }

    @Test func attemptsComeBackOldestFirst() async throws {
        try await withStore { store, _ in try await Contract.checkAttemptsComeBackOldestFirst(store) }
    }

    @Test func keepsOnlyTheLastTwentyAttempts() async throws {
        try await withStore { store, _ in try await Contract.checkKeepsOnlyTheLastTwentyAttempts(store) }
    }

    @Test func exactlyTwentyAreAllKept() async throws {
        try await withStore { store, _ in try await Contract.checkExactlyTwentyAreAllKept(store) }
    }

    @Test func bestAttemptIsTheHighestShareAndLatestWinsTies() async throws {
        try await withStore { store, _ in
            try await Contract.checkBestAttemptIsTheHighestShareAndLatestWinsTies(store)
        }
    }

    @Test func hasPassedIsTrueOnceAnyAttemptPassed() async throws {
        try await withStore { store, _ in try await Contract.checkHasPassedIsTrueOnceAnyAttemptPassed(store) }
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await withStore { store, _ in try await Contract.checkEraseClearsAndIsIdempotent(store) }
    }

    @Test func appendAfterEraseStartsFresh() async throws {
        try await withStore { store, _ in try await Contract.checkAppendAfterEraseStartsFresh(store) }
    }

    // MARK: File behaviour

    @Test func missingFileLoadsEmptyAndIsNotCreatedByLoad() async throws {
        try await withStore { store, fileURL in
            let loaded = try await store.load()
            #expect(loaded.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func dataSurvivesANewStoreOnTheSameFile() async throws {
        try await withStore { store, fileURL in
            let first = Contract.attempt(day: 1)
            let second = Contract.attempt(day: 2, correct: 90)
            try await store.append(first)
            try await store.append(second)

            let reopened = FileExamResultStore(fileURL: fileURL)
            let reopenedAttempts = try await reopened.load()
            #expect(reopenedAttempts == [first, second])
            let third = Contract.attempt(day: 3, correct: 95)
            try await reopened.append(third)
            let all = try await store.load()
            #expect(all == [first, second, third])
        }
    }

    @Test func appendCreatesMissingParentDirectories() async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory
                .appendingPathComponent("zz-nested", isDirectory: true)
                .appendingPathComponent("zz-deeper", isDirectory: true)
                .appendingPathComponent("exam.json")
            let store = FileExamResultStore(fileURL: fileURL)
            try await store.append(Contract.attempt())
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func fileHoldsTheSchemaVersionAndNothingButTheListedFields() async throws {
        try await withStore { store, fileURL in
            let levels = [
                ExamLevelScore(level: 2, correct: 7, total: 10),
                ExamLevelScore(level: nil, correct: 60, total: 80)
            ]
            try await store.append(Contract.attempt(day: 1, correct: 67, total: 90, passed: false, levels: levels))

            let data = try bytes(of: fileURL)
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(Set(object.keys) == ["schemaVersion", "attempts"])
            #expect(object["schemaVersion"] as? Int == 1)

            let attempts = try #require(object["attempts"] as? [[String: Any]])
            let attempt = try #require(attempts.first)
            #expect(attempts.count == 1)
            #expect(Set(attempt.keys) == ["date", "correct", "total", "passed", "levels"])
            #expect(attempt["correct"] as? Int == 67)
            #expect(attempt["total"] as? Int == 90)
            #expect(attempt["passed"] as? Bool == false)

            let storedLevels = try #require(attempt["levels"] as? [[String: Any]])
            #expect(storedLevels.count == 2)
            #expect(Set(storedLevels[0].keys) == ["level", "correct", "total"])
            #expect(storedLevels[0]["level"] as? Int == 2)
            // A level of nil leaves the key out rather than writing a null.
            #expect(Set(storedLevels[1].keys) == ["correct", "total"])
        }
    }

    // MARK: Corrupt, future and unreadable files

    @Test(arguments: [
        "not json at all",
        "",
        "[]",
        "{}",
        "{\"schemaVersion\":1}",
        "{\"schemaVersion\":\"1\",\"attempts\":[]}",
        "{\"schemaVersion\":1,\"attempts\":42}",
        "{\"schemaVersion\":1,\"attempts\":[{\"correct\":1}]}"
    ])
    func undecodableFileThrowsCorruptAndIsNeverTouched(contents: String) async throws {
        try await withStore { store, fileURL in
            try write(contents, to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ExamResultStoreError.corrupt) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func futureSchemaVersionIsRejectedAndNeverTouched() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"attempts\":[],\"extra\":true}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ExamResultStoreError.unsupportedSchemaVersion(2)) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func futureSchemaIsReportedEvenWhenItsShapeDiffers() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":7,\"results\":{}}", to: fileURL)
            await #expect(throws: ExamResultStoreError.unsupportedSchemaVersion(7)) { _ = try await store.load() }
        }
    }

    @Test func appendOnCorruptFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ExamResultStoreError.corrupt) { try await store.append(Contract.attempt()) }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func appendOnFutureSchemaFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":3,\"attempts\":[]}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ExamResultStoreError.unsupportedSchemaVersion(3)) {
                try await store.append(Contract.attempt())
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func eraseRemovesADamagedFile() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            let loaded = try await store.load()
            #expect(loaded.isEmpty)
        }
    }

    @Test func fileURLThatIsADirectoryIsUnreadable() async throws {
        try await Contract.withScratchDirectory { directory in
            let store = FileExamResultStore(fileURL: directory)
            await #expect(throws: ExamResultStoreError.unreadable) { _ = try await store.load() }
        }
    }

    // MARK: Erase

    @Test func eraseLeavesNoFile() async throws {
        try await withStore { store, fileURL in
            try await store.append(Contract.attempt())
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            try await store.erase()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func eraseNeverDeletesADirectory() async throws {
        try await Contract.withScratchDirectory { directory in
            let sentinel = directory.appendingPathComponent("zz-sentinel.txt")
            try write("zz", to: sentinel)
            let store = FileExamResultStore(fileURL: directory)

            await #expect(throws: ExamResultStoreError.eraseFailed) { try await store.erase() }
            #expect(FileManager.default.fileExists(atPath: sentinel.path))
        }
    }

    // MARK: Write failure

    @Test func unwritableLocationThrowsAStoreErrorWithoutLeakingDetail() async throws {
        try await Contract.withScratchDirectory { directory in
            let blocker = directory.appendingPathComponent("zz-blocker")
            try write("zz", to: blocker)
            let store = FileExamResultStore(fileURL: blocker.appendingPathComponent("exam.json"))

            do throws(ExamResultStoreError) {
                try await store.append(Contract.attempt())
                Issue.record("expected append to throw")
            } catch {
                let isStoreFailure = error == .writeFailed || error == .unreadable
                #expect(isStoreFailure)
                let description = String(describing: error)
                #expect(!description.contains(directory.lastPathComponent))
            }
        }
    }
}
