import BLTCore
import BLTProgress
import Foundation
import Testing

struct ProgressSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let known = ItemID(rawValue: "zz-known")
    private let variant = ItemID(rawValue: "zz-variant")
    private let unknown = ItemID(rawValue: "zz-unknown")

    private func summary(
        reviews: [ReviewState] = [],
        attempts: [AttemptRecord] = []
    ) -> ProgressSummary {
        let snapshot = ProgressSnapshot(
            reviews: Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) }),
            attempts: attempts
        )
        return ProgressSummary(snapshot: snapshot, knownItems: [known, variant], variantItems: [variant], now: now)
    }

    private func attempt(_ id: ItemID, _ outcome: Outcome) -> AttemptRecord {
        AttemptRecord(itemID: id, outcome: outcome, date: now)
    }

    private func review(
        _ id: ItemID,
        repetitions: Int = 2,
        outcome: Outcome = .correct,
        due: Date
    ) -> ReviewState {
        ReviewState(
            itemID: id,
            repetitions: repetitions,
            intervalDays: 6,
            easeFactor: 2.5,
            due: due,
            lastOutcome: outcome,
            lastReviewed: now
        )
    }

    @Test func emptySnapshotGivesZerosAndNilAccuracy() {
        let result = summary()
        #expect(result.registerAccuracy == nil)
        #expect(result.learnedCount == 0)
        #expect(result.dueCount == 0)
        #expect(result.attemptCount == 0)
    }

    @Test func accuracyIsNilWithoutVariantItemAttempts() {
        let result = summary(attempts: [attempt(known, .correct), attempt(known, .wrongRegister)])
        #expect(result.registerAccuracy == nil)
        #expect(result.attemptCount == 2)
    }

    @Test func accuracyIsCorrectOverCorrectPlusWrongRegister() throws {
        let result = summary(attempts: [
            attempt(variant, .correct),
            attempt(variant, .correct),
            attempt(variant, .correct),
            attempt(variant, .wrongRegister)
        ])
        let accuracy = try #require(result.registerAccuracy)
        #expect(abs(accuracy - 0.75) < 1e-9)
    }

    @Test func wrongAttemptsAreExcludedFromAccuracy() throws {
        let onlyWrong = summary(attempts: [attempt(variant, .wrong), attempt(variant, .wrong)])
        #expect(onlyWrong.registerAccuracy == nil)
        #expect(onlyWrong.attemptCount == 2)

        let mixed = summary(attempts: [attempt(variant, .correct), attempt(variant, .wrong), attempt(variant, .wrong)])
        let accuracy = try #require(mixed.registerAccuracy)
        #expect(abs(accuracy - 1.0) < 1e-9)
    }

    @Test func unknownItemsAreIgnoredEverywhere() {
        let result = summary(
            reviews: [review(unknown, due: now.addingTimeInterval(-10))],
            attempts: [attempt(unknown, .correct), attempt(unknown, .wrongRegister)]
        )
        #expect(result.learnedCount == 0)
        #expect(result.dueCount == 0)
        #expect(result.attemptCount == 0)
        #expect(result.registerAccuracy == nil)
    }

    @Test func variantItemOutsideKnownItemsIsNotCounted() {
        let snapshot = ProgressSnapshot(reviews: [:], attempts: [attempt(variant, .correct)])
        let result = ProgressSummary(snapshot: snapshot, knownItems: [known], variantItems: [variant], now: now)
        #expect(result.registerAccuracy == nil)
        #expect(result.attemptCount == 0)
    }

    @Test func learnedCountUsesIsLearnedOnKnownItems() {
        let result = summary(reviews: [
            review(known, repetitions: 2, outcome: .correct, due: now.addingTimeInterval(86400)),
            review(variant, repetitions: 5, outcome: .wrongRegister, due: now.addingTimeInterval(86400)),
            review(unknown, repetitions: 9, outcome: .correct, due: now.addingTimeInterval(86400))
        ])
        #expect(result.learnedCount == 1)
    }

    @Test func dueBoundaryCountsAsDue() {
        let result = summary(reviews: [
            review(known, due: now),
            review(variant, due: now.addingTimeInterval(1))
        ])
        #expect(result.dueCount == 1)

        let both = summary(reviews: [
            review(known, due: now),
            review(variant, due: now.addingTimeInterval(-1))
        ])
        #expect(both.dueCount == 2)
    }
}
