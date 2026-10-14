import BLTDesign
import BLTProgress
import Foundation
import Observation

/// Drives the streak screen: loads the practice log once, computes the `StreakSummary` at the injected
/// moment, and decides which month the calendar shows and how far it may be paged.
///
/// Nothing here writes: a log that cannot be read is shown as a calm message and left exactly as it is.
@MainActor
@Observable
final class StreakViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// The log could not be read. Nothing has been changed.
        case failed
    }

    private(set) var phase = Phase.loading
    private(set) var summary: StreakSummary
    /// The first instant of the month the calendar shows.
    private(set) var shownMonth: Date
    private(set) var deadlineText = StreakDeadlineText.noStreak

    let calendar: Calendar
    let locale: Locale

    private let log: any PracticeLogStore
    private let now: @Sendable () -> Date
    private let calculator: StreakCalculator
    private var range: StreakMonthRange

    init(
        practiceLog: any PracticeLogStore,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date,
        locale: Locale = .current,
        dailyGoal: Int = StreakCalculator.defaultDailyGoal
    ) {
        self.log = practiceLog
        self.calendar = calendar
        self.locale = locale
        self.now = now
        self.calculator = StreakCalculator(dailyGoal: dailyGoal)
        self.summary = .empty(dailyGoal: dailyGoal)
        let range = StreakMonthRange(firstPractised: nil, now: now(), calendar: calendar)
        self.range = range
        self.shownMonth = range.last
    }

    // MARK: Reading state

    /// The moment the screen treats as "now" (for today's marker in the calendar).
    var today: Date { now() }

    /// Day states for the month calendar, keyed by the start of each day.
    var monthStates: [Date: StreakDayState] {
        StreakDayStates.states(for: summary, calendar: calendar)
    }

    var canShowPreviousMonth: Bool { range.canGoPrevious(from: shownMonth) }
    var canShowNextMonth: Bool { range.canGoNext(from: shownMonth) }

    var previousMonthLabel: String { "Previous month, \(title(range.previous(from: shownMonth)))" }
    var nextMonthLabel: String { "Next month, \(title(range.next(from: shownMonth)))" }

    // MARK: Actions

    /// Reads the log and works out the summary. Safe to call again (Try again after a failure).
    func load() async {
        let moment = now()
        do {
            let log = try await log.load()
            summary = calculator.summary(for: log, now: moment, calendar: calendar)
            let firstPractised = summary.practisedDays.min().flatMap { $0.startOfDay(in: calendar) }
            range = StreakMonthRange(firstPractised: firstPractised, now: moment, calendar: calendar)
            shownMonth = range.clamped(shownMonth)
            deadlineText = StreakDeadlineText.text(
                for: summary.deadline, now: moment, calendar: calendar, locale: locale
            )
            phase = .loaded
        } catch {
            phase = .failed
        }
    }

    private func title(_ month: Date) -> String {
        StreakLabels.monthTitle(month, calendar: calendar, locale: locale)
    }

    func showPreviousMonth() {
        shownMonth = range.previous(from: shownMonth)
    }

    func showNextMonth() {
        shownMonth = range.next(from: shownMonth)
    }
}
