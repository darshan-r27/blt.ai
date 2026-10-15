import BLTProgress
import Foundation

/// The streak deadline in plain words ("Practise by 7:40 PM tomorrow."). Pure: the caller passes the moment,
/// the calendar (whose time zone decides what "today" and "tomorrow" mean) and the locale (which decides how
/// the time is written).
enum StreakDeadlineText {
    static let noStreak = "Finish a chapter to start a new streak."
    static let freezeCovers = "If you miss it, a freeze will keep your streak going."

    static func text(for deadline: StreakDeadline?, now: Date, calendar: Calendar, locale: Locale) -> String {
        guard let deadline else { return noStreak }
        let base = "Practise by \(whenPhrase(deadline.practiseBy, now: now, calendar: calendar, locale: locale))."
        return deadline.freezeWouldCover ? "\(base) \(freezeCovers)" : base
    }

    private static func whenPhrase(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let time = date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        )
        if calendar.isDate(date, inSameDayAs: now) { return "\(time) today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "\(time) tomorrow"
        }
        let day = date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide)
        )
        return "\(time) on \(day)"
    }
}
