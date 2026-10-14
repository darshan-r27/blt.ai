import Foundation

/// Maps day states onto the seven days of a week. Pure functions over an injected calendar.
public enum StreakWeek {
    /// The start of each of the seven days of the calendar week containing `today`, from the calendar's
    /// first weekday (so a Monday-first locale gets a Monday-first strip).
    public static func dates(containing today: Date, calendar: Calendar) -> [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// The seven days of the week containing `today`, each with its state from `states`.
    /// `states` is keyed by the start of the day in `calendar`; a missing day is `.empty`.
    public static func days(
        containing today: Date,
        states: [Date: StreakDayState],
        calendar: Calendar
    ) -> [StreakDay] {
        dates(containing: today, calendar: calendar).map { StreakDay(date: $0, state: states[$0] ?? .empty) }
    }

    /// True when `date` is on a later calendar day than `today`.
    public static func isFuture(_ date: Date, today: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: today)
    }
}
