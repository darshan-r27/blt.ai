import Foundation

/// The part of the day when the app does not send reminders. Stored as minutes after midnight, so the
/// window can span midnight (the default, 10 pm to 8 am, does).
///
/// The start is inside the window and the end is outside it: a moment exactly at the end is allowed, a
/// moment exactly at the start is not. A window whose start equals its end is empty (no quiet hours).
public struct QuietHours: Sendable, Equatable, Codable {
    public static let minutesPerDay = 24 * 60

    /// 10 pm to 8 am.
    public static let standard = QuietHours(startMinute: 22 * 60, endMinute: 8 * 60)

    /// No quiet hours at all.
    public static let none = QuietHours(startMinute: 0, endMinute: 0)

    /// Minutes after midnight, `0..<1440`, when quiet hours begin.
    public let startMinute: Int

    /// Minutes after midnight, `0..<1440`, when quiet hours end.
    public let endMinute: Int

    /// Values outside `0..<1440` wrap around the clock (1500 is 1:00 am) rather than failing.
    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = Self.wrapped(startMinute)
        self.endMinute = Self.wrapped(endMinute)
    }

    public init(startHour: Int, endHour: Int) {
        self.init(startMinute: startHour * 60, endMinute: endHour * 60)
    }

    public var isEmpty: Bool {
        startMinute == endMinute
    }

    public var spansMidnight: Bool {
        startMinute > endMinute
    }

    /// Whether a minute of the day (`0..<1440`) is inside the quiet window.
    public func contains(minuteOfDay minute: Int) -> Bool {
        if isEmpty {
            return false
        }
        let minute = Self.wrapped(minute)
        if spansMidnight {
            return minute >= startMinute || minute < endMinute
        }
        return minute >= startMinute && minute < endMinute
    }

    /// Whether a moment falls inside the quiet window, read on the wall clock of `calendar`.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return contains(minuteOfDay: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    /// The most recent moment at or before `date` when the quiet window began, or `nil` if `date` is not
    /// inside the window.
    public func windowStart(containing date: Date, calendar: Calendar) -> Date? {
        guard contains(date, calendar: calendar) else {
            return nil
        }
        let wallClock = DateComponents(hour: startMinute / 60, minute: startMinute % 60)
        // Looking backward from one second later makes a moment exactly at the start find itself.
        return calendar.nextDate(
            after: date.addingTimeInterval(1),
            matching: wallClock,
            matchingPolicy: .nextTime,
            direction: .backward
        )
    }

    private static func wrapped(_ minute: Int) -> Int {
        ((minute % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}
