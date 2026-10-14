import Foundation

/// Plain-language lines for the streak screens that are not the deadline. Pure, so they can be tested.
enum StreakCopy {
    static let maximumFreezes = "You are holding the most freezes you can."
    static let dailyGoalMet = "Daily goal met"
    static let logNotUpdated = "Your streak could not be updated this time. Your answers are safe."
    static let loadFailed = "Your streak could not be read. Nothing has been changed."

    static func nextFreeze(daysUntil: Int?) -> String {
        guard let days = daysUntil else { return maximumFreezes }
        let count = max(days, 1)
        return count == 1 ? "1 more day to your next freeze" : "\(count) more days to your next freeze"
    }

    /// "1 day" or "12 days", for the longest streak and the number of goal days.
    static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(max(days, 0)) days"
    }
}
