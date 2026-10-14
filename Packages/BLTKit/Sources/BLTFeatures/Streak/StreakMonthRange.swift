import Foundation

/// Which months the streak screen's calendar may show: from the first month the learner practised in to the
/// current month, no earlier and no later. All dates are the first instant of a month in `calendar`.
struct StreakMonthRange: Equatable {
    let first: Date
    let last: Date
    let calendar: Calendar

    /// `firstPractised` is any date in the earliest month with practice, or `nil` when there is none (the
    /// range is then just the current month). A first month after `now` is clamped to the current month.
    init(firstPractised: Date?, now: Date, calendar: Calendar) {
        let current = Self.monthStart(now, calendar: calendar)
        let earliest = firstPractised.map { Self.monthStart($0, calendar: calendar) } ?? current
        self.first = min(earliest, current)
        self.last = current
        self.calendar = calendar
    }

    func clamped(_ month: Date) -> Date {
        min(max(Self.monthStart(month, calendar: calendar), first), last)
    }

    func canGoPrevious(from month: Date) -> Bool {
        Self.monthStart(month, calendar: calendar) > first
    }

    func canGoNext(from month: Date) -> Bool {
        Self.monthStart(month, calendar: calendar) < last
    }

    /// The month before `month`, or `month` itself when it is the first allowed.
    func previous(from month: Date) -> Date {
        guard canGoPrevious(from: month), let moved = calendar.date(byAdding: .month, value: -1, to: month) else {
            return clamped(month)
        }
        return clamped(moved)
    }

    /// The month after `month`, or `month` itself when it is the current one.
    func next(from month: Date) -> Date {
        guard canGoNext(from: month), let moved = calendar.date(byAdding: .month, value: 1, to: month) else {
            return clamped(month)
        }
        return clamped(moved)
    }

    private static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
