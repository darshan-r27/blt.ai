import BLTProgress
import Foundation
import Testing

struct FileProgressStoreTests {
    private typealias Contract = ProgressStoreContract

    /// Runs `body` with a store whose file lives in a fresh scratch directory.
    private func withStore(_ body: (FileProgressStore, URL) async throws -> Void) async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory.appendingPathComponent("progress.json")
            try await body(FileProgressStore(fileURL: fileURL), fileURL)
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

    @Test func roundTrip() async throws {
        try await withStore { store, _ in try await Contract.checkRoundTrip(store) }
    }

    @Test func replacingReviewKeepsOneEntryPerItem() async throws {
        try await withStore { store, _ in try await Contract.checkReplacingReviewKeepsOneEntryPerItem(store) }
    }

    @Test func concurrentRecordsLoseNothing() async throws {
        try await withStore { store, _ in try await Contract.checkConcurrentRecordsLoseNothing(store) }
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await withStore { store, _ in try await Contract.checkEraseClearsAndIsIdempotent(store) }
    }

    @Test func recordAfterEraseStartsFresh() async throws {
        try await withStore { store, _ in try await Contract.checkRecordAfterEraseStartsFresh(store) }
    }

    // MARK: File behaviour

    @Test func missingFileLoadsEmptyAndIsNotCreatedByLoad() async throws {
        try await withStore { store, fileURL in
            let snapshot = try await store.load()
            #expect(snapshot == .empty)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func dataSurvivesANewStoreOnTheSameFile() async throws {
        try await withStore { store, fileURL in
            let review = Contract.review("zz-a")
            let attempt = Contract.attempt("zz-a")
            try await store.record(attempt, updating: review)

            let reopened = FileProgressStore(fileURL: fileURL)
            let snapshot = try await reopened.load()
            #expect(snapshot.reviews == [review.itemID: review])
            #expect(snapshot.attempts == [attempt])
        }
    }

    @Test func recordCreatesMissingParentDirectories() async throws {
        try await Contract.withScratchDirectory { directory in
            let fileURL = directory
                .appendingPathComponent("zz-nested", isDirectory: true)
                .appendingPathComponent("zz-deeper", isDirectory: true)
                .appendingPathComponent("progress.json")
            let store = FileProgressStore(fileURL: fileURL)
            try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func fileIsJSONWithSchemaVersionOne() async throws {
        try await withStore { store, fileURL in
            try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))

            let data = try bytes(of: fileURL)
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["schemaVersion"] as? Int == 1)
            #expect((object["reviews"] as? [Any])?.count == 1)
            #expect((object["attempts"] as? [Any])?.count == 1)
        }
    }

    // MARK: Corrupt, future and unreadable files

    @Test(arguments: [
        "not json at all",
        "",
        "[]",
        "{}",
        "{\"schemaVersion\":1}",
        "{\"schemaVersion\":1,\"reviews\":\"zz\",\"attempts\":[]}",
        "{\"schemaVersion\":\"1\",\"reviews\":[],\"attempts\":[]}"
    ])
    func undecodableFileThrowsCorruptAndIsNeverTouched(contents: String) async throws {
        try await withStore { store, fileURL in
            try write(contents, to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProgressStoreError.corrupt) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func duplicateReviewEntriesAreCorrupt() async throws {
        try await withStore { store, fileURL in
            let review = "{\"itemID\":\"zz-a\",\"repetitions\":1,\"intervalDays\":1,\"easeFactor\":2.5,"
                + "\"due\":0,\"lastOutcome\":\"correct\",\"lastReviewed\":0}"
            try write("{\"schemaVersion\":1,\"reviews\":[\(review),\(review)],\"attempts\":[]}", to: fileURL)

            await #expect(throws: ProgressStoreError.corrupt) { _ = try await store.load() }
        }
    }

    @Test func futureSchemaVersionIsRejectedAndNeverTouched() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"reviews\":[],\"attempts\":[],\"zz\":true}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProgressStoreError.unsupportedSchemaVersion(2)) { _ = try await store.load() }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func futureSchemaIsReportedEvenWhenItsShapeDiffers() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":7,\"entries\":{}}", to: fileURL)
            await #expect(throws: ProgressStoreError.unsupportedSchemaVersion(7)) { _ = try await store.load() }
        }
    }

    @Test func recordOnCorruptFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProgressStoreError.corrupt) {
                try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func recordOnFutureSchemaFileThrowsAndDoesNotOverwrite() async throws {
        try await withStore { store, fileURL in
            try write("{\"schemaVersion\":2,\"reviews\":[],\"attempts\":[]}", to: fileURL)
            let before = try bytes(of: fileURL)

            await #expect(throws: ProgressStoreError.unsupportedSchemaVersion(2)) {
                try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))
            }
            let after = try bytes(of: fileURL)
            #expect(after == before)
        }
    }

    @Test func eraseRemovesACorruptFile() async throws {
        try await withStore { store, fileURL in
            try write("not json at all", to: fileURL)
            try await store.eraseAll()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            let snapshot = try await store.load()
            #expect(snapshot == .empty)
        }
    }

    @Test func fileURLThatIsADirectoryIsUnreadable() async throws {
        try await Contract.withScratchDirectory { directory in
            let store = FileProgressStore(fileURL: directory)
            await #expect(throws: ProgressStoreError.unreadable) { _ = try await store.load() }
        }
    }

    // MARK: Erase

    @Test func eraseLeavesNoFile() async throws {
        try await withStore { store, fileURL in
            try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            try await store.eraseAll()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
            try await store.eraseAll()
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func eraseNeverDeletesADirectory() async throws {
        try await Contract.withScratchDirectory { directory in
            let sentinel = directory.appendingPathComponent("zz-sentinel.txt")
            try write("zz", to: sentinel)
            let store = FileProgressStore(fileURL: directory)

            await #expect(throws: ProgressStoreError.eraseFailed) { try await store.eraseAll() }
            #expect(FileManager.default.fileExists(atPath: sentinel.path))
        }
    }

    // MARK: Write failure

    @Test func unwritableLocationThrowsAStoreErrorWithoutLeakingDetail() async throws {
        try await Contract.withScratchDirectory { directory in
            let blocker = directory.appendingPathComponent("zz-blocker")
            try write("zz", to: blocker)
            let store = FileProgressStore(fileURL: blocker.appendingPathComponent("progress.json"))

            do throws(ProgressStoreError) {
                try await store.record(Contract.attempt("zz-a"), updating: Contract.review("zz-a"))
                Issue.record("expected record to throw")
            } catch {
                let isStoreFailure = error == ProgressStoreError.writeFailed || error == ProgressStoreError.unreadable
                #expect(isStoreFailure)
                let description = String(describing: error)
                #expect(!description.contains(directory.lastPathComponent))
            }
        }
    }
}
