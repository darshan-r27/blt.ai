import Foundation

/// The streak rules (plan.md "Daily practice"), as pure functions of a `PracticeLog`, a moment and a
/// calendar. No clock, no time zone and no disk is read: the caller passes `now` and a `Calendar` whose
/// `timeZone` is the learner's current one.
///
/// Rules:
/// - **Window.** A streak survives while each session finishes within 24 hours (exactly 24 h counts) of
///   the one before. The 24 hours are real elapsed time, so a daylight-saving change can make "the same
///   time tomorrow" 23 or 25 hours away; 25 hours needs a freeze.
/// - **The number.** The count is calendar dates (in `calendar`) with a session inside an unbroken chain,
///   so practising every 23 hours still adds only one per date. Dates covered by a freeze do not count.
/// - **Freezes.** One is earned each time the chain reaches a multiple of 7 days; at most 2 are held (an
///   earned one beyond that is lost). A gap longer than 24 hours misses `ceil(gap / 24 h) - 1` windows
///   and uses one freeze per window, automatically. If there are not enough, the chain breaks: the
///   current streak is 0, the longest is kept, and the freezes held stay for the next chain.
/// - **Now.** The gap from the last session to `now` is treated like a gap to a new session, so a freeze
///   is already spent (in the summary only) once a window has passed without practice.
/// - **Goal.** Sessions on today's date (in `calendar`) are chapters; the goal is met at `dailyGoal`.
/// - Sessions with no answers are ignored.
public struct StreakCalculator: Sendable {
    /// The length of one streak window.
    public static let window: TimeInterval = 24 * 60 * 60
    public static let daysPerFreeze = 7
    public static let maximumFreezes = 2
    public static let defaultDailyGoal = 2

    public let dailyGoal: Int

    public init(dailyGoal: Int = StreakCalculator.defaultDailyGoal) {
        precondition(dailyGoal >= 1, "daily goal must be at least 1")
        self.dailyGoal = dailyGoal
    }

    /// The streak, freezes, goal and calendar sets for `log` at `now`.
    public func summary(for log: PracticeLog, now: Date, calendar: Calendar) -> StreakSummary {
        let sessions = log.sessions.filter(\.countsTowardStreak)
        guard let last = sessions.last else { return .empty(dailyGoal: dailyGoal) }

        let chain = walkChain(sessions, calendar: calendar)
        let pending = Self.missedWindows(from: last.finishedAt, to: now)
        let alive = pending <= chain.freezes
        let current = alive ? chain.length : 0
        let freezesAvailable = alive ? chain.freezes - pending : chain.freezes

        var frozenDays = chain.frozenDays
        if alive {
            frozenDays.formUnion(Self.coveredDays(after: last.finishedAt, windows: pending, calendar: calendar))
        }

        let perDay = Dictionary(grouping: sessions) { PracticeDay($0.finishedAt, calendar: calendar) }
            .mapValues(\.count)
        let goalMetDays = Set(perDay.filter { $0.value >= dailyGoal }.keys)
        let chaptersToday = perDay[PracticeDay(now, calendar: calendar)] ?? 0

        return StreakSummary(
            currentStreak: current,
            longestStreak: chain.longest,
            freezesAvailable: freezesAvailable,
            daysUntilNextFreeze: freezesAvailable >= Self.maximumFreezes
                ? nil : Self.daysUntilNextFreeze(after: current),
            chaptersToday: chaptersToday,
            dailyGoal: dailyGoal,
            goalDays: goalMetDays.count,
            lastSessionAt: last.finishedAt,
            deadline: alive ? StreakDeadline(
                practiseBy: last.finishedAt.addingTimeInterval(Double(pending + 1) * Self.window),
                freezeWouldCover: freezesAvailable >= 1
            ) : nil,
            practisedDays: Set(perDay.keys),
            goalMetDays: goalMetDays,
            frozenDays: frozenDays
        )
    }

    /// How many whole 24-hour windows pass with no session between `previous` and `next`: 0 when `next` is
    /// within 24 hours (or earlier), otherwise `ceil(gap / 24 h) - 1`.
    static func missedWindows(from previous: Date, to next: Date) -> Int {
        let gap = next.timeIntervalSince(previous)
        guard gap > window else { return 0 }
        return Int((gap / window).rounded(.up)) - 1
    }

    /// The dates on which each of `windows` consecutive missed windows after `start` ends.
    private static func coveredDays(after start: Date, windows: Int, calendar: Calendar) -> Set<PracticeDay> {
        Set(stride(from: 1, through: windows, by: 1).map {
            PracticeDay(start.addingTimeInterval(Double($0) * window), calendar: calendar)
        })
    }

    private static func daysUntilNextFreeze(after streak: Int) -> Int {
        daysPerFreeze - streak % daysPerFreeze
    }

    /// The result of replaying the log in time order.
    private struct Chain {
        var length = 0
        var longest = 0
        var freezes = 0
        var lastDay: PracticeDay?
        var frozenDays: Set<PracticeDay> = []
    }

    /// Replays `sessions` (already filtered and sorted) and returns the state after the last one.
    private func walkChain(_ sessions: [PracticeSession], calendar: Calendar) -> Chain {
        var chain = Chain()
        var previous: Date?
        for session in sessions {
            if let previous {
                let missed = Self.missedWindows(from: previous, to: session.finishedAt)
                if missed > chain.freezes {
                    chain.length = 0
                    chain.lastDay = nil
                } else {
                    chain.freezes -= missed
                    chain.frozenDays.formUnion(Self.coveredDays(after: previous, windows: missed, calendar: calendar))
                }
            }
            let day = PracticeDay(session.finishedAt, calendar: calendar)
            if day != chain.lastDay {
                chain.lastDay = day
                chain.length += 1
                if chain.length % Self.daysPerFreeze == 0 {
                    chain.freezes = min(Self.maximumFreezes, chain.freezes + 1)
                }
            }
            chain.longest = max(chain.longest, chain.length)
            previous = session.finishedAt
        }
        return chain
    }
}
