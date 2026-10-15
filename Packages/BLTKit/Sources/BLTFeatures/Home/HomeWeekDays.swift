import BLTDesign
import BLTProgress
import Foundation

/// Maps a streak summary onto the seven days of the week strip. Pure functions over an injected calendar.
enum HomeWeekDays {
    /// The seven days of the week containing `now` (from the calendar's first weekday), each with its mark:
    /// goal met beats practised beats freeze beats empty. A day still to come is always empty.
    static func days(for summary: StreakSummary, now: Date, calendar: Calendar) -> [StreakDay] {
        var states: [Date: StreakDayState] = [:]
        for date in StreakWeek.dates(containing: now, calendar: calendar) {
            states[date] = state(
                of: PracticeDay(date, calendar: calendar),
                isFuture: StreakWeek.isFuture(date, today: now, calendar: calendar),
                in: summary
            )
        }
        return StreakWeek.days(containing: now, states: states, calendar: calendar)
    }

    private static func state(of day: PracticeDay, isFuture: Bool, in summary: StreakSummary) -> StreakDayState {
        if isFuture { return .empty }
        if summary.goalMetDays.contains(day) { return .goalMet }
        if summary.practisedDays.contains(day) { return .practised }
        if summary.frozenDays.contains(day) { return .freeze }
        return .empty
    }
}
