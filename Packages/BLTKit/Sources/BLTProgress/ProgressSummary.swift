import BLTCore
import Foundation

/// The figures on the Progress screen. Only items in `knownItems` (the current catalog) are counted,
/// so progress left over from removed content cannot inflate or skew anything.
public struct ProgressSummary: Sendable, Equatable {
    /// correct / (correct + wrongRegister) over attempts on known variant items; `nil` when there are none.
    /// A `.wrong` attempt is excluded: it says nothing about register knowledge.
    public let registerAccuracy: Double?
    public let learnedCount: Int
    public let dueCount: Int
    public let attemptCount: Int

    public init(snapshot: ProgressSnapshot, knownItems: Set<ItemID>, variantItems: Set<ItemID>, now: Date) {
        let reviews = snapshot.reviews.values.filter { knownItems.contains($0.itemID) }
        learnedCount = reviews.filter(\.isLearned).count
        dueCount = reviews.filter { $0.isDue(at: now) }.count

        let attempts = snapshot.attempts.filter { knownItems.contains($0.itemID) }
        attemptCount = attempts.count

        let registerAttempts = attempts.filter { variantItems.contains($0.itemID) }
        let correct = registerAttempts.filter { $0.outcome == .correct }.count
        let wrongRegister = registerAttempts.filter { $0.outcome == .wrongRegister }.count
        let denominator = correct + wrongRegister
        registerAccuracy = denominator == 0 ? nil : Double(correct) / Double(denominator)
    }
}
