import BLTDesign
import BLTProgress
import Foundation

/// The daily-practice figures Home shows, derived from `practiceSummary` and the lesson list.
extension HomeViewModel {
    /// The number on the flame chip.
    var streakCount: Int {
        practiceSummary.currentStreak
    }

    /// The chip is lit only once something was finished today; before that it is an outline.
    var isStreakLit: Bool {
        practiceSummary.practisedToday
    }

    /// The Today card, with the lesson a tap opens (the same one the Continue card opens).
    var todayCard: HomeTodayCard {
        HomeTodayCard(summary: practiceSummary, nextLesson: continueLesson)
    }

    /// The seven days of this week with their marks.
    var weekDays: [StreakDay] {
        HomeWeekDays.days(for: practiceSummary, now: currentTime, calendar: practiceCalendar)
    }

    /// "1 freeze left", or "No freezes left", plus how far away the next one is while a streak runs.
    var freezeLine: String {
        Self.freezeLine(for: practiceSummary)
    }

    nonisolated static func freezeLine(for summary: StreakSummary) -> String {
        let held = StreakLabels.freezes(summary.freezesAvailable)
        var line = "\(held.prefix(1).uppercased())\(held.dropFirst()) left"
        if summary.currentStreak > 0, let days = summary.daysUntilNextFreeze {
            line += ", next in \(days) \(days == 1 ? "day" : "days")"
        }
        return line
    }

    /// What Home says when the practice log could not be read. Calm, and says the lessons still work.
    nonisolated static let practiceUnreadableNote =
        "Your practice streak could not be read just now. Your lessons still work, and nothing was changed."
}
