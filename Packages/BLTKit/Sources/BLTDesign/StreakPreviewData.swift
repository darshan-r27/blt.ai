import Foundation

#if DEBUG
/// Fixed dates and day states shared by the previews of the streak views. Fake data, only used by `#Preview`.
enum StreakPreviewData {
    static let locale = Locale(identifier: "en_US")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Wednesday 14 October 2026.
    static let today: Date = date(year: 2026, month: 10, day: 14)

    /// A run of flames, a freeze, and a few goal-met days up to yesterday; today not yet practised.
    static let states: [Date: StreakDayState] = {
        var states: [Date: StreakDayState] = [:]
        for day in 1...13 {
            states[date(year: 2026, month: 10, day: day)] = day % 4 == 0 ? .goalMet : .practised
        }
        states[date(year: 2026, month: 10, day: 6)] = .freeze
        states[date(year: 2026, month: 10, day: 7)] = .empty
        return states
    }()

    static func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
#endif
