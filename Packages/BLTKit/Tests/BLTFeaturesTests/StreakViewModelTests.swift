import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

private actor UnreadablePracticeLogStore: PracticeLogStore {
    private(set) var erased = false
    func load() async throws(PracticeLogError) -> PracticeLog { throw .corrupt }
    func append(_ session: PracticeSession) async throws(PracticeLogError) { throw .corrupt }
    func erase() async throws(PracticeLogError) { erased = true }
}

@MainActor
struct StreakViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private let locale = Locale(identifier: "en_US")

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func model(_ log: some PracticeLogStore) -> StreakViewModel {
        let fixed = now
        return StreakViewModel(practiceLog: log, calendar: calendar, now: { fixed }, locale: locale)
    }

    private func store(daysAgo: [Double]) -> InMemoryPracticeLogStore {
        let sessions = daysAgo.map { PracticeSession(finishedAt: now.addingTimeInterval(-$0 * 86_400), answered: 10) }
        return InMemoryPracticeLogStore(initial: PracticeLog(sessions: sessions))
    }

    private func monthStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    @Test func loadingShowsTheStreakAndTheDeadline() async {
        let model = model(store(daysAgo: [2, 1, 0]))
        #expect(model.phase == .loading)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.summary.currentStreak == 3)
        #expect(model.deadlineText.hasPrefix("Practise by "))
        #expect(model.deadlineText.hasSuffix("tomorrow.") || model.deadlineText.contains("freeze"))
    }

    @Test func anEmptyLogIsALoadedScreenWithNoStreak() async {
        let model = model(InMemoryPracticeLogStore())
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.summary.currentStreak == 0)
        #expect(model.deadlineText == StreakDeadlineText.noStreak)
        #expect(!model.canShowPreviousMonth)
        #expect(!model.canShowNextMonth)
        #expect(model.monthStates.isEmpty)
    }

    @Test func theCalendarStartsOnTheCurrentMonth() async {
        let model = model(store(daysAgo: [0]))
        await model.load()
        #expect(model.shownMonth == monthStart(now))
    }

    @Test func pagingBackStopsAtTheFirstPractisedMonth() async {
        // Practice 40 days ago, so the first practised month is one or two months before the current one.
        let model = model(store(daysAgo: [40, 0]))
        await model.load()
        var steps = 0
        while model.canShowPreviousMonth, steps < 5 {
            model.showPreviousMonth()
            steps += 1
        }
        let firstMonth = monthStart(now.addingTimeInterval(-40 * 86_400))
        #expect(model.shownMonth == firstMonth)
        #expect(steps >= 1 && steps <= 2)
        model.showPreviousMonth()
        #expect(model.shownMonth == firstMonth)
    }

    @Test func pagingForwardStopsAtTheCurrentMonth() async {
        let model = model(store(daysAgo: [40, 0]))
        await model.load()
        model.showPreviousMonth()
        #expect(model.canShowNextMonth)
        model.showNextMonth()
        #expect(model.shownMonth == monthStart(now))
        #expect(!model.canShowNextMonth)
        model.showNextMonth()
        #expect(model.shownMonth == monthStart(now))
    }

    @Test func theMonthStatesCarryPractisedAndGoalMetDays() async throws {
        let model = model(store(daysAgo: [1, 0, 0.01]))
        await model.load()
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        #expect(model.monthStates[today] == .goalMet)
        #expect(model.monthStates[yesterday] == .practised)
    }

    @Test func anUnreadableLogShowsAFailureAndIsNeverErased() async {
        let log = UnreadablePracticeLogStore()
        let model = model(log)
        await model.load()
        #expect(model.phase == .failed)
        #expect(await log.erased == false)
    }

    @Test func theMonthButtonsNameTheMonthTheyGoTo() async {
        let model = model(store(daysAgo: [40, 0]))
        await model.load()
        #expect(model.nextMonthLabel.hasPrefix("Next month, "))
        #expect(model.previousMonthLabel.hasPrefix("Previous month, "))
    }
}
