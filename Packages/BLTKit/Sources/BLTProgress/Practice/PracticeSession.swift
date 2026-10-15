import Foundation

/// One finished practice session (a "chapter"), as stored in the practice log.
///
/// The app records a session when it reaches the summary screen with at least one answer. A record
/// carries only the finish time and how many questions were answered: no item IDs, no content.
public struct PracticeSession: Sendable, Equatable, Codable {
    public let finishedAt: Date
    public let answered: Int

    public init(finishedAt: Date, answered: Int) {
        self.finishedAt = finishedAt
        self.answered = answered
    }

    /// A session with no answers does not count towards the streak or the daily goal. The store refuses to
    /// record one and the calculator ignores any that reach it another way (for example a hand-edited file).
    public var countsTowardStreak: Bool { answered >= 1 }
}
