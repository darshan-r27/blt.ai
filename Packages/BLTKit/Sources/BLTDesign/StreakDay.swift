import Foundation

/// One day on the week strip: its date (the start of the day in the calendar the view is given) and its state.
public struct StreakDay: Sendable, Equatable, Hashable, Identifiable {
    public let date: Date
    public let state: StreakDayState

    public var id: Date { date }

    public init(date: Date, state: StreakDayState) {
        self.date = date
        self.state = state
    }
}
