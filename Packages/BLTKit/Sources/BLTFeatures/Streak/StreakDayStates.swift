import BLTDesign
import BLTProgress
import Foundation

/// Maps the day sets of a `StreakSummary` to the states the week strip and month calendar draw.
///
/// Keys are the start of each day in `calendar`, which is how `StreakWeek` and `MonthGrid` look dates up.
/// A day with a session shows as practised (or goal met when it reached the daily goal); a day that only a
/// freeze covered shows as a freeze; a day that is both keeps the practice, because that is what happened.
enum StreakDayStates {
    static func states(for summary: StreakSummary, calendar: Calendar) -> [Date: StreakDayState] {
        var states: [Date: StreakDayState] = [:]
        for day in summary.frozenDays {
            if let date = day.startOfDay(in: calendar) { states[date] = .freeze }
        }
        for day in summary.practisedDays {
            if let date = day.startOfDay(in: calendar) { states[date] = .practised }
        }
        for day in summary.goalMetDays {
            if let date = day.startOfDay(in: calendar) { states[date] = .goalMet }
        }
        return states
    }
}
