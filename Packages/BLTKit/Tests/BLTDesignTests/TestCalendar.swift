import Foundation

/// Fixed Gregorian UTC calendars for the streak tests, so nothing depends on the machine's time zone or locale.
enum TestCalendar {
    static let locale = Locale(identifier: "en_US")

    static func make(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    static let sunday = make(firstWeekday: 1)
    static let monday = make(firstWeekday: 2)

    static func date(year: Int, month: Int, day: Int, calendar: Calendar = monday) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
