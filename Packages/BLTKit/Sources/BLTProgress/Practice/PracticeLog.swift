import Foundation

/// The finished sessions of one course, oldest first. Everything about streaks is computed from this
/// value (see `StreakCalculator`); nothing derived is stored.
public struct PracticeLog: Sendable, Equatable {
    public static let empty = PracticeLog(sessions: [])

    /// Ordered by `finishedAt`, oldest first; sessions finishing at the same instant keep insertion order.
    public let sessions: [PracticeSession]

    /// Sorts `sessions` by finish time. Records with no answers are kept as given; they are ignored when
    /// the streak is computed and are never added by `appending`.
    public init(sessions: [PracticeSession]) {
        self.sessions = sessions.enumerated()
            .sorted { lhs, rhs in
                lhs.element.finishedAt == rhs.element.finishedAt
                    ? lhs.offset < rhs.offset
                    : lhs.element.finishedAt < rhs.element.finishedAt
            }
            .map(\.element)
    }

    /// The log with `session` added in time order. A session with no answers is ignored and the log is
    /// returned unchanged (documented decision: "opening and leaving" is not practice).
    public func appending(_ session: PracticeSession) -> PracticeLog {
        guard session.countsTowardStreak else { return self }
        return PracticeLog(sessions: sessions + [session])
    }
}
