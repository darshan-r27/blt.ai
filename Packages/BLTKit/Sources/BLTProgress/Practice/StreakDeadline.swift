import Foundation

/// When the learner must finish their next session to keep the streak going.
public struct StreakDeadline: Sendable, Equatable {
    /// The end of the current 24-hour window: the last session plus 24 hours, moved on by one window for
    /// each freeze already used since then. Never earlier than `now` when the streak is alive.
    public let practiseBy: Date
    /// Whether a freeze would cover the next window if `practiseBy` is missed.
    public let freezeWouldCover: Bool

    public init(practiseBy: Date, freezeWouldCover: Bool) {
        self.practiseBy = practiseBy
        self.freezeWouldCover = freezeWouldCover
    }
}
