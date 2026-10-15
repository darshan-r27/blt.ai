/// The streak lengths that get a bigger celebration and a badge. Pure, so the rule is easy to test.
public enum StreakMilestone {
    /// Streak days that count as milestones (plan.md, "Daily practice", decision 8).
    public static let days: [Int] = [7, 30, 50, 100]

    public static func isMilestone(_ count: Int) -> Bool {
        days.contains(count)
    }

    /// The highest milestone passed or reached when the streak moved from `previousCount` to `count`,
    /// or nil when none was. A streak that did not grow reaches nothing, so repeating a day never re-celebrates.
    public static func reached(previousCount: Int, count: Int) -> Int? {
        guard count > previousCount else { return nil }
        return days.last { $0 > previousCount && $0 <= count }
    }

    /// The first milestone strictly above `count`, or nil once every milestone is behind it.
    public static func next(after count: Int) -> Int? {
        days.first { $0 > count }
    }
}
