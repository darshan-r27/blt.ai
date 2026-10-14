/// What one calendar day looks like on the week strip and the month calendar.
///
/// Plain values only: later chunks map the streak calculator's output (in `BLTProgress`) to these.
public enum StreakDayState: Sendable, Equatable, Hashable, CaseIterable {
    /// No practice that day (or a day still to come).
    case empty
    /// At least one finished session: the day counts toward the streak.
    case practised
    /// The daily goal was met as well: a flame with a green check.
    case goalMet
    /// A streak freeze covered a missed day: a snowflake.
    case freeze

    /// True for the two states that show a flame.
    public var showsFlame: Bool {
        self == .practised || self == .goalMet
    }
}
