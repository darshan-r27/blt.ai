import BLTCore
import BLTProgress
import Foundation
import Testing

struct ReviewStateTests {
    private func state(
        repetitions: Int,
        outcome: Outcome,
        due: Date = Date(timeIntervalSince1970: 1000)
    ) -> ReviewState {
        ReviewState(
            itemID: ItemID(rawValue: "zz-1"),
            repetitions: repetitions,
            intervalDays: 1,
            easeFactor: 2.5,
            due: due,
            lastOutcome: outcome,
            lastReviewed: Date(timeIntervalSince1970: 0)
        )
    }

    @Test(arguments: [
        (0, Outcome.correct, false),
        (1, Outcome.correct, false),
        (2, Outcome.correct, true),
        (5, Outcome.correct, true),
        (2, Outcome.wrongRegister, false),
        (5, Outcome.wrong, false)
    ])
    func learnedTruthTable(repetitions: Int, outcome: Outcome, expected: Bool) {
        #expect(state(repetitions: repetitions, outcome: outcome).isLearned == expected)
    }

    @Test func dueIncludesTheExactBoundary() {
        let due = Date(timeIntervalSince1970: 1000)
        let review = state(repetitions: 1, outcome: .correct, due: due)
        #expect(review.isDue(at: due))
        #expect(review.isDue(at: due.addingTimeInterval(1)))
        #expect(!review.isDue(at: due.addingTimeInterval(-1)))
    }

    @Test func snapshotStartsEmpty() {
        #expect(ProgressSnapshot.empty.reviews.isEmpty)
        #expect(ProgressSnapshot.empty.attempts.isEmpty)
    }
}
