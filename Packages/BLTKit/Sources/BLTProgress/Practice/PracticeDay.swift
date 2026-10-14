import Foundation

/// A calendar date (year, month, day) with no time and no time zone of its own. Which date an instant
/// falls on depends on the `Calendar` (and so the time zone) passed in; the streak is always computed
/// with the learner's current one, so travelling can move a session to a neighbouring date.
public struct PracticeDay: Sendable, Hashable, Comparable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The date `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// Midnight at the start of this date in `calendar`, or `nil` if the date does not exist there.
    public func startOfDay(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public static func < (lhs: PracticeDay, rhs: PracticeDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
