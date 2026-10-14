import Foundation

/// Every VoiceOver label and visible summary string of the streak visuals, built by pure functions so the
/// wording is unit-tested. Dates are formatted with the calendar and locale the caller passes in.
public enum StreakLabels {
    // MARK: Streak count

    /// "13 day streak, 1 freeze left"; without a freeze count, "13 day streak"; at zero, "No streak yet".
    public static func streak(count: Int, freezesLeft: Int? = nil) -> String {
        let days = max(count, 0)
        let base = days == 0 ? "No streak yet" : "\(days) day streak"
        guard let freezesLeft else { return base }
        return "\(base), \(freezes(max(freezesLeft, 0))) left"
    }

    /// "no freezes", "1 freeze" or "2 freezes".
    public static func freezes(_ count: Int) -> String {
        switch count {
        case ...0: "no freezes"
        case 1: "1 freeze"
        default: "\(count) freezes"
        }
    }

    /// "7 day milestone", spoken and shown on the badge at the end of a session.
    public static func milestone(days: Int) -> String {
        "\(days) day milestone"
    }

    // MARK: Today's goal

    /// "Today: 1 of 2 chapters"; once the goal is met, ", daily goal met" is added.
    public static func today(chaptersDone: Int, goal: Int) -> String {
        let target = max(goal, 1)
        let done = min(max(chaptersDone, 0), target)
        let noun = target == 1 ? "chapter" : "chapters"
        let base = "Today: \(done) of \(target) \(noun)"
        return done >= target ? "\(base), daily goal met" : base
    }

    // MARK: Week strip and calendar

    public static let week = "This week"

    /// What a day's mark means. A day still to come reads "upcoming" whatever state it was given.
    public static func state(_ state: StreakDayState, isFuture: Bool = false) -> String {
        guard !isFuture else { return "upcoming" }
        switch state {
        case .empty: return "no practice"
        case .practised: return "practised, streak day"
        case .goalMet: return "practised, daily goal met"
        case .freeze: return "streak freeze used"
        }
    }

    /// "Tuesday, October 13, today, practised, streak day".
    public static func day(
        date: Date,
        state: StreakDayState,
        today: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let isFuture = StreakWeek.isFuture(date, today: today, calendar: calendar)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        var parts = [dayName(date, calendar: calendar, locale: locale)]
        if isToday { parts.append("today") }
        parts.append(self.state(state, isFuture: isFuture))
        return parts.joined(separator: ", ")
    }

    /// "Tuesday, October 13".
    public static func dayName(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.wide).day()
        return date.formatted(style)
    }

    /// "October 2026".
    public static func monthTitle(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.wide).year()
        return date.formatted(style)
    }

    /// "12 practice days, 3 with the daily goal met, 1 freeze used".
    public static func monthSummary(_ summary: MonthGrid.Summary) -> String {
        let days = summary.practisedDays == 1 ? "1 practice day" : "\(summary.practisedDays) practice days"
        var parts = [days]
        if summary.goalDays > 0 {
            parts.append("\(summary.goalDays) with the daily goal met")
        }
        if summary.freezeDays > 0 {
            parts.append("\(freezes(summary.freezeDays)) used")
        }
        return parts.joined(separator: ", ")
    }
}
