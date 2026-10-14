import Foundation

/// The cells of a month calendar: rows of seven, starting on the calendar's first weekday, with blank cells
/// before the first and after the last day. Pure, so the layout rules are tested without a view.
public struct MonthGrid: Sendable, Equatable {
    public struct Cell: Sendable, Equatable, Identifiable {
        /// Position in the grid, unique within one month (blank cells have no date to identify them).
        public let id: Int
        /// The start of the day, or nil for a blank cell.
        public let date: Date?
        /// Day of the month (1...31), or nil for a blank cell.
        public let day: Int?
    }

    /// How a month looked, for the text summary under the calendar.
    public struct Summary: Sendable, Equatable {
        /// Days with a flame (practised or goal met).
        public let practisedDays: Int
        /// Days with the daily goal met.
        public let goalDays: Int
        /// Days a freeze covered.
        public let freezeDays: Int

        public init(practisedDays: Int, goalDays: Int, freezeDays: Int) {
            self.practisedDays = practisedDays
            self.goalDays = goalDays
            self.freezeDays = freezeDays
        }
    }

    public let rows: [[Cell]]

    /// - Parameter month: any date inside the month to show.
    public init(month: Date, calendar: Calendar) {
        guard
            let interval = calendar.dateInterval(of: .month, for: month),
            let dayRange = calendar.range(of: .day, in: .month, for: month)
        else {
            rows = []
            return
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells = (0..<leadingBlanks).map { Cell(id: $0, date: nil, day: nil) }
        for day in dayRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start)
            cells.append(Cell(id: cells.count, date: date, day: day))
        }
        while cells.count % 7 != 0 {
            cells.append(Cell(id: cells.count, date: nil, day: nil))
        }
        rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Counts for the month, from states keyed by the start of the day.
    public func summary(states: [Date: StreakDayState]) -> Summary {
        let shown = rows.flatMap { $0 }.compactMap(\.date).map { states[$0] ?? .empty }
        return Summary(
            practisedDays: shown.filter(\.showsFlame).count,
            goalDays: shown.filter { $0 == .goalMet }.count,
            freezeDays: shown.filter { $0 == .freeze }.count
        )
    }

    /// One-letter weekday symbols for the header row, starting on the calendar's first weekday.
    public static func weekdayHeaders(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
