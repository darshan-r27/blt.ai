import Foundation

/// Everything the Home, session-end, streak and settings screens show about daily practice, computed by
/// `StreakCalculator` from a `PracticeLog` at one moment.
public struct StreakSummary: Sendable, Equatable {
    /// Calendar dates practised inside the unbroken chain that is still alive at `now`; 0 when there is
    /// none (never practised, or the chain broke).
    public let currentStreak: Int
    /// The longest chain ever, including a broken one. Kept after a reset.
    public let longestStreak: Int
    /// Freezes held, after subtracting any that already cover a missed window since the last session.
    public let freezesAvailable: Int
    /// Streak days still needed to earn the next freeze; `nil` when the learner already holds the maximum.
    public let daysUntilNextFreeze: Int?
    /// Finished sessions on today's date (in the calendar's time zone).
    public let chaptersToday: Int
    public let dailyGoal: Int
    /// At least one session today.
    public let practisedToday: Bool
    /// `chaptersToday >= dailyGoal`.
    public let goalMet: Bool
    /// How many dates, ever, had at least `dailyGoal` sessions.
    public let goalDays: Int
    /// The finish time of the latest session, if any.
    public let lastSessionAt: Date?
    /// `nil` when there is no live streak to protect.
    public let deadline: StreakDeadline?
    /// Every date with at least one session (for the month calendar).
    public let practisedDays: Set<PracticeDay>
    /// Every date with at least `dailyGoal` sessions.
    public let goalMetDays: Set<PracticeDay>
    /// Dates on which a freeze covered a missed 24-hour window (shown as a snowflake).
    public let frozenDays: Set<PracticeDay>

    public init(
        currentStreak: Int,
        longestStreak: Int,
        freezesAvailable: Int,
        daysUntilNextFreeze: Int?,
        chaptersToday: Int,
        dailyGoal: Int,
        goalDays: Int,
        lastSessionAt: Date?,
        deadline: StreakDeadline?,
        practisedDays: Set<PracticeDay>,
        goalMetDays: Set<PracticeDay>,
        frozenDays: Set<PracticeDay>
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.freezesAvailable = freezesAvailable
        self.daysUntilNextFreeze = daysUntilNextFreeze
        self.chaptersToday = chaptersToday
        self.dailyGoal = dailyGoal
        self.practisedToday = chaptersToday >= 1
        self.goalMet = chaptersToday >= dailyGoal
        self.goalDays = goalDays
        self.lastSessionAt = lastSessionAt
        self.deadline = deadline
        self.practisedDays = practisedDays
        self.goalMetDays = goalMetDays
        self.frozenDays = frozenDays
    }

    /// The summary of a log with no sessions.
    public static func empty(dailyGoal: Int = StreakCalculator.defaultDailyGoal) -> StreakSummary {
        StreakSummary(
            currentStreak: 0,
            longestStreak: 0,
            freezesAvailable: 0,
            daysUntilNextFreeze: StreakCalculator.daysPerFreeze,
            chaptersToday: 0,
            dailyGoal: dailyGoal,
            goalDays: 0,
            lastSessionAt: nil,
            deadline: nil,
            practisedDays: [],
            goalMetDays: [],
            frozenDays: []
        )
    }
}
