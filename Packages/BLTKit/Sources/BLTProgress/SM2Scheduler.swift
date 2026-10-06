import BLTCore
import Foundation

/// SM-2 style scheduler (MVP_PLAN section 1). Pure and deterministic: no clock, no calendar, no randomness.
///
/// Outcome mapping: `.correct` is quality 5, `.wrongRegister` quality 3, `.wrong` quality 1.
/// The next interval after the second repetition uses the ease factor the item had *before* this
/// review's update, as in the original SuperMemo description (interval step, then EF step).
public struct SM2Scheduler: Scheduler {
    public static let initialEaseFactor = 2.5
    public static let easeFactorFloor = 1.3
    public static let maxIntervalDays = 365

    private static let secondsPerDay: TimeInterval = 86400

    public init() {}

    public func review(_ previous: ReviewState?, itemID: ItemID, outcome: Outcome, at now: Date) -> ReviewState {
        let repetitions = previous?.repetitions ?? 0
        let intervalDays = previous?.intervalDays ?? 0
        let easeFactor = previous?.easeFactor ?? Self.initialEaseFactor

        let newRepetitions: Int
        let newInterval: Int
        switch outcome {
        case .correct:
            newRepetitions = repetitions + 1
            switch newRepetitions {
            case 1:
                newInterval = 1
            case 2:
                newInterval = 6
            default:
                newInterval = Self.clampedInterval((Double(intervalDays) * easeFactor).rounded())
            }
        case .wrongRegister:
            newRepetitions = repetitions
            newInterval = 1
        case .wrong:
            newRepetitions = 0
            newInterval = 0
        }

        return ReviewState(
            itemID: itemID,
            repetitions: newRepetitions,
            intervalDays: newInterval,
            easeFactor: Self.updatedEaseFactor(easeFactor, quality: Self.quality(for: outcome)),
            due: now.addingTimeInterval(Double(newInterval) * Self.secondsPerDay),
            lastOutcome: outcome,
            lastReviewed: now
        )
    }

    private static func quality(for outcome: Outcome) -> Int {
        switch outcome {
        case .correct: 5
        case .wrongRegister: 3
        case .wrong: 1
        }
    }

    /// EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)), floored at 1.3.
    private static func updatedEaseFactor(_ easeFactor: Double, quality: Int) -> Double {
        let miss = Double(5 - quality)
        let updated = easeFactor + (0.1 - miss * (0.08 + miss * 0.02))
        return max(easeFactorFloor, updated)
    }

    private static func clampedInterval(_ days: Double) -> Int {
        Int(min(max(days, 1), Double(maxIntervalDays)))
    }
}
