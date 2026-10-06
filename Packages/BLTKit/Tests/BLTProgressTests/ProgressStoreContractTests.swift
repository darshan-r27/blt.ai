import BLTCore
import BLTProgress
import Foundation
import Testing

/// Behaviour every `ProgressStore` must share. Each store's test file runs these against a fresh store,
/// so the in-memory store is held to exactly the contract the file store is.
enum ProgressStoreContract {
    // MARK: Fixtures (obviously fake IDs, fractional dates so precision loss would show)

    static func review(_ id: String, repetitions: Int = 1, outcome: Outcome = .correct) -> ReviewState {
        ReviewState(
            itemID: ItemID(rawValue: id),
            repetitions: repetitions,
            intervalDays: 6,
            easeFactor: 2.36,
            due: Date(timeIntervalSince1970: 1_700_086_400.123456),
            lastOutcome: outcome,
            lastReviewed: Date(timeIntervalSince1970: 1_700_000_000.654321)
        )
    }

    static func attempt(
        _ id: String,
        outcome: Outcome = .correct,
        at seconds: Double = 1_700_000_000.5
    ) -> AttemptRecord {
        AttemptRecord(itemID: ItemID(rawValue: id), outcome: outcome, date: Date(timeIntervalSince1970: seconds))
    }

    /// A unique directory under Application Support (not the temporary directory, which the guard script
    /// bans), removed when `body` finishes.
    static func withScratchDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("zz-BLTProgressTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    // MARK: Shared checks

    static func checkNewStoreLoadsEmpty(_ store: any ProgressStore) async throws {
        let snapshot = try await store.load()
        #expect(snapshot == .empty)
    }

    static func checkRoundTrip(_ store: any ProgressStore) async throws {
        let firstReview = review("zz-a", repetitions: 1, outcome: .correct)
        let secondReview = review("zz-b", repetitions: 0, outcome: .wrong)
        let firstAttempt = attempt("zz-a", outcome: .correct, at: 1_700_000_001.25)
        let secondAttempt = attempt("zz-b", outcome: .wrong, at: 1_700_000_002.75)

        try await store.record(firstAttempt, updating: firstReview)
        try await store.record(secondAttempt, updating: secondReview)

        let snapshot = try await store.load()
        #expect(snapshot.reviews == [firstReview.itemID: firstReview, secondReview.itemID: secondReview])
        #expect(snapshot.attempts == [firstAttempt, secondAttempt])
    }

    static func checkReplacingReviewKeepsOneEntryPerItem(_ store: any ProgressStore) async throws {
        let first = review("zz-a", repetitions: 1, outcome: .correct)
        let second = review("zz-a", repetitions: 2, outcome: .correct)
        let third = review("zz-a", repetitions: 0, outcome: .wrong)
        let attempts = [
            attempt("zz-a", outcome: .correct, at: 1),
            attempt("zz-a", outcome: .correct, at: 2),
            attempt("zz-a", outcome: .wrong, at: 3)
        ]

        try await store.record(attempts[0], updating: first)
        try await store.record(attempts[1], updating: second)
        try await store.record(attempts[2], updating: third)

        let snapshot = try await store.load()
        #expect(snapshot.reviews.count == 1)
        #expect(snapshot.reviews[third.itemID] == third)
        #expect(snapshot.attempts == attempts)
    }

    static func checkConcurrentRecordsLoseNothing(_ store: any ProgressStore, count: Int = 50) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<count {
                group.addTask {
                    let id = "zz-\(index)"
                    try await store.record(attempt(id, at: Double(index)), updating: review(id))
                }
            }
            try await group.waitForAll()
        }

        let snapshot = try await store.load()
        #expect(snapshot.reviews.count == count)
        #expect(snapshot.attempts.count == count)
        #expect(Set(snapshot.attempts.map(\.itemID)).count == count)
    }

    static func checkEraseClearsAndIsIdempotent(_ store: any ProgressStore) async throws {
        try await store.eraseAll()
        try await store.record(attempt("zz-a"), updating: review("zz-a"))
        let snapshot = try await store.load()
        #expect(snapshot != .empty)

        try await store.eraseAll()
        let erased = try await store.load()
        #expect(erased == .empty)

        try await store.eraseAll()
        let erasedAgain = try await store.load()
        #expect(erasedAgain == .empty)
    }

    static func checkRecordAfterEraseStartsFresh(_ store: any ProgressStore) async throws {
        try await store.record(attempt("zz-a"), updating: review("zz-a"))
        try await store.eraseAll()
        let fresh = review("zz-b")
        let freshAttempt = attempt("zz-b")
        try await store.record(freshAttempt, updating: fresh)

        let snapshot = try await store.load()
        #expect(snapshot.reviews == [fresh.itemID: fresh])
        #expect(snapshot.attempts == [freshAttempt])
    }
}
