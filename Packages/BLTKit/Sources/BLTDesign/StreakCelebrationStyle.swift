/// How big the end-of-session celebration is.
public enum StreakCelebrationStyle: Sendable, Equatable {
    /// The streak did not grow (a second session the same day): the flame and number show, with no burst.
    case quiet
    /// The streak grew: a keyframe burst and a success haptic.
    case burst
    /// The streak reached a milestone: a bigger burst and a badge naming the milestone.
    case milestone(days: Int)

    public init(previousCount: Int, count: Int) {
        if let days = StreakMilestone.reached(previousCount: previousCount, count: count) {
            self = .milestone(days: days)
        } else if count > previousCount {
            self = .burst
        } else {
            self = .quiet
        }
    }

    /// The milestone length, for styles that carry one.
    public var milestoneDays: Int? {
        if case let .milestone(days) = self { days } else { nil }
    }
}
