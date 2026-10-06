import BLTCore
import BLTProgress
import Foundation
import Testing

struct SM2SchedulerTests {
    private let scheduler = SM2Scheduler()
    private let itemID = ItemID(rawValue: "zz-item-1")
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func apply(_ outcomes: [Outcome], from initial: ReviewState? = nil) -> [ReviewState] {
        var states: [ReviewState] = []
        var current = initial
        for outcome in outcomes {
            let next = scheduler.review(current, itemID: itemID, outcome: outcome, at: start)
            states.append(next)
            current = next
        }
        return states
    }

    private func state(repetitions: Int, interval: Int, ease: Double) -> ReviewState {
        ReviewState(
            itemID: itemID,
            repetitions: repetitions,
            intervalDays: interval,
            easeFactor: ease,
            due: start,
            lastOutcome: .correct,
            lastReviewed: start
        )
    }

    @Test func correctSequenceFollowsTheFormula() {
        // Interval uses the EF held before this review's update: 6 * 2.7 = 16.2 -> 16, then 16 * 2.8 = 44.8 -> 45.
        let repetitions = [1, 2, 3, 4]
        let intervals = [1, 6, 16, 45]
        let easeFactors = [2.6, 2.7, 2.8, 2.9]
        let states = apply([.correct, .correct, .correct, .correct])
        #expect(states.map(\.repetitions) == repetitions)
        #expect(states.map(\.intervalDays) == intervals)
        for (actual, want) in zip(states.map(\.easeFactor), easeFactors) {
            #expect(abs(actual - want) < 1e-9)
        }
        #expect(states.allSatisfy { $0.lastOutcome == .correct })
    }

    @Test func firstAttemptTreatsNilAsFreshState() {
        let result = scheduler.review(nil, itemID: itemID, outcome: .correct, at: start)
        #expect(result.itemID == itemID)
        #expect(result.repetitions == 1)
        #expect(result.intervalDays == 1)
        #expect(abs(result.easeFactor - 2.6) < 1e-9)
        #expect(result.lastReviewed == start)
        #expect(result.due == start.addingTimeInterval(86400))
    }

    @Test func dueIsNowPlusIntervalDaysInSeconds() {
        let states = apply([.correct, .correct])
        #expect(states[1].due == start.addingTimeInterval(6 * 86400))
    }

    @Test func wrongRegisterKeepsRepetitionsAndDropsEase() {
        let previous = state(repetitions: 3, interval: 15, ease: 2.5)
        let result = scheduler.review(previous, itemID: itemID, outcome: .wrongRegister, at: start)
        #expect(result.repetitions == 3)
        #expect(result.intervalDays == 1)
        #expect(abs(result.easeFactor - 2.36) < 1e-9)
        #expect(result.lastOutcome == .wrongRegister)
        #expect(result.due == start.addingTimeInterval(86400))
        #expect(!result.isLearned)
    }

    @Test func wrongRegisterOnFirstAttemptStaysAtZeroRepetitions() {
        let result = scheduler.review(nil, itemID: itemID, outcome: .wrongRegister, at: start)
        #expect(result.repetitions == 0)
        #expect(result.intervalDays == 1)
        #expect(abs(result.easeFactor - 2.36) < 1e-9)
    }

    @Test func wrongResetsRepetitionsAndIsDueNow() {
        let previous = state(repetitions: 4, interval: 30, ease: 2.5)
        let result = scheduler.review(previous, itemID: itemID, outcome: .wrong, at: start)
        #expect(result.repetitions == 0)
        #expect(result.intervalDays == 0)
        #expect(result.due == start)
        #expect(result.isDue(at: start))
        #expect(abs(result.easeFactor - 1.96) < 1e-9)
        #expect(result.lastOutcome == .wrong)
    }

    @Test func recoveryAfterWrongRestartsTheLadder() {
        let states = apply([.correct, .correct, .wrong, .correct, .correct])
        #expect(states[2].repetitions == 0)
        #expect(states[3].repetitions == 1)
        #expect(states[3].intervalDays == 1)
        #expect(states[4].repetitions == 2)
        #expect(states[4].intervalDays == 6)
    }

    @Test func easeFactorNeverDropsBelowFloor() {
        let wrongs = apply(Array(repeating: .wrong, count: 20))
        #expect(wrongs.allSatisfy { $0.easeFactor >= 1.3 })
        #expect(abs((wrongs.last?.easeFactor ?? 0) - 1.3) < 1e-9)

        let registerMisses = apply(Array(repeating: .wrongRegister, count: 30))
        #expect(registerMisses.allSatisfy { $0.easeFactor >= 1.3 })
        #expect(abs((registerMisses.last?.easeFactor ?? 0) - 1.3) < 1e-9)
    }

    @Test func intervalNeverExceedsCap() {
        let states = apply(Array(repeating: .correct, count: 40))
        #expect(states.allSatisfy { $0.intervalDays <= 365 })
        #expect(states.last?.intervalDays == 365)

        let huge = state(repetitions: 9, interval: 365, ease: 3.0)
        let capped = scheduler.review(huge, itemID: itemID, outcome: .correct, at: start)
        #expect(capped.intervalDays == 365)
    }

    @Test func sameInputGivesSameOutput() {
        let previous = state(repetitions: 2, interval: 6, ease: 2.7)
        for outcome in Outcome.allCases {
            let first = scheduler.review(previous, itemID: itemID, outcome: outcome, at: start)
            let second = SM2Scheduler().review(previous, itemID: itemID, outcome: outcome, at: start)
            #expect(first == second)
        }
    }
}
