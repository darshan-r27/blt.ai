import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

// Home's daily practice: the chip, the Today card, the week strip, a log that cannot be read, and Reset.
// Fake `zz` text and fake dates only.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    calendar.firstWeekday = 2
    return calendar
}()

private func moment(day: Int, hour: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
}

/// Wednesday 14 October 2026, noon.
private let now = moment(day: 14, hour: 12)

private func session(day: Int, hour: Int) -> PracticeSession {
    PracticeSession(finishedAt: moment(day: day, hour: hour), answered: 10)
}

/// A practice log that can fail on load or erase and counts how often it was asked to erase.
private actor StubPracticeLog: PracticeLogStore {
    private var log: PracticeLog
    private let loadError: PracticeLogError?
    private let eraseError: PracticeLogError?
    private(set) var eraseCount = 0
    private(set) var appendCount = 0

    init(log: PracticeLog = .empty, loadError: PracticeLogError? = nil, eraseError: PracticeLogError? = nil) {
        self.log = log
        self.loadError = loadError
        self.eraseError = eraseError
    }

    func load() async throws(PracticeLogError) -> PracticeLog {
        if let loadError { throw loadError }
        return log
    }

    func append(_ session: PracticeSession) async throws(PracticeLogError) {
        appendCount += 1
        log = log.appending(session)
    }

    func erase() async throws(PracticeLogError) {
        eraseCount += 1
        if let eraseError { throw eraseError }
        log = .empty
    }
}

private func completed(_ scenario: Scenario) -> [ReviewState] {
    scenario.items.map {
        ReviewState(
            itemID: $0.id,
            repetitions: 1,
            intervalDays: 1,
            easeFactor: 2.5,
            due: now,
            lastOutcome: .correct,
            lastReviewed: now
        )
    }
}

@MainActor
private func loaded(
    log: any PracticeLogStore,
    scenarios: [Scenario] = [PreviewCatalog.lesson("zz-a", title: "zz Lesson A", level: nil)],
    completedLessons: [Scenario] = []
) async -> HomeViewModel {
    let states = completedLessons.flatMap(completed)
    let model = HomeViewModel(
        dependencies: AppDependencies(
            catalog: Catalog(scenarios: scenarios, issues: []),
            language: .tamil,
            store: InMemoryProgressStore(
                initial: ProgressSnapshot(
                    reviews: Dictionary(uniqueKeysWithValues: states.map { ($0.itemID, $0) }),
                    attempts: []
                )
            ),
            scheduler: SM2Scheduler(),
            now: { now }
        ),
        practiceLog: log,
        calendar: calendar
    )
    await model.load()
    return model
}

@MainActor
struct HomeViewModelPracticeTests {
    @Test func aNewLearnerSeesAnUnlitChipAtZero() async {
        let model = await loaded(log: InMemoryPracticeLogStore())
        #expect(model.streakCount == 0)
        #expect(model.isStreakLit == false)
        #expect(model.practiceError == nil)
    }

    @Test func theChipIsLitOnlyOnceTodayHasAFinishedChapter() async {
        let yesterdayOnly = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [
            session(day: 12, hour: 18), session(day: 13, hour: 18)
        ]))
        let before = await loaded(log: yesterdayOnly)
        #expect(before.streakCount == 2)
        #expect(before.isStreakLit == false)

        let withToday = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [
            session(day: 12, hour: 18), session(day: 13, hour: 18), session(day: 14, hour: 9)
        ]))
        let after = await loaded(log: withToday)
        #expect(after.streakCount == 3)
        #expect(after.isStreakLit)
    }

    @Test func theTodayCardFollowsTheChaptersFinishedToday() async {
        let none = await loaded(log: InMemoryPracticeLogStore())
        #expect(none.todayCard.done == 0)
        #expect(none.todayCard.nextChapter?.number == 1)

        let one = await loaded(
            log: InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(day: 14, hour: 9)]))
        )
        #expect(one.todayCard.done == 1)
        #expect(one.todayCard.nextChapter?.number == 2)

        let two = await loaded(log: InMemoryPracticeLogStore(
            initial: PracticeLog(sessions: [session(day: 14, hour: 9), session(day: 14, hour: 10)])
        ))
        #expect(two.todayCard.goalMet)
        #expect(two.todayCard.nextChapter == nil)
    }

    @Test func theTodayCardOpensTheSameLessonAsTheContinueCard() async {
        let model = await loaded(log: InMemoryPracticeLogStore())
        #expect(model.todayCard.nextLesson?.id == model.continueLesson?.id)
        #expect(model.todayCard.nextLesson?.id == ScenarioID(rawValue: "zz-a"))
    }

    @Test func withEveryLessonCompleteThereIsNothingToPractise() async {
        let only = PreviewCatalog.lesson("zz-a", title: "zz Lesson A", level: nil)
        let model = await loaded(log: InMemoryPracticeLogStore(), scenarios: [only], completedLessons: [only])
        #expect(model.continueLesson == nil)
        #expect(model.todayCard.hasNothingToPractise)
        #expect(model.todayCard.canStart == false)
    }

    @Test func theWeekStripShowsThisWeeksPractice() async {
        let model = await loaded(log: InMemoryPracticeLogStore(initial: PracticeLog(sessions: [
            session(day: 13, hour: 9), session(day: 13, hour: 10), session(day: 14, hour: 9)
        ])))
        #expect(model.weekDays.map(\.state) == [.empty, .goalMet, .practised, .empty, .empty, .empty, .empty])
    }

    @Test func anUnreadableLogLeavesTheScenariosUsable() async {
        let log = StubPracticeLog(loadError: .corrupt)
        let model = await loaded(log: log)
        #expect(model.practiceError == .corrupt)
        #expect(model.loadError == nil)
        #expect(model.scenarios.count == 1)
        #expect(model.continueLesson != nil)
        #expect(model.streakCount == 0)
        #expect(model.hasLoaded)
    }

    @Test func anUnreadableLogIsNeverErasedOrWrittenByLoading() async {
        let log = StubPracticeLog(loadError: .corrupt)
        let model = await loaded(log: log)
        await model.loadPractice()
        #expect(await log.eraseCount == 0)
        #expect(await log.appendCount == 0)
    }

    @Test func theUnreadableNoteSaysTheLessonsStillWork() {
        #expect(HomeViewModel.practiceUnreadableNote.contains("lessons still work"))
    }

    @Test func resetErasesThePracticeLogToo() async {
        let log = StubPracticeLog(log: PracticeLog(sessions: [session(day: 13, hour: 18), session(day: 14, hour: 9)]))
        let model = await loaded(log: log)
        #expect(model.streakCount == 2)
        await model.confirmReset()
        #expect(await log.eraseCount == 1)
        #expect(model.resetError == nil)
        #expect(model.streakCount == 0)
        #expect(model.todayCard.done == 0)
    }

    @Test func aFailedLogEraseIsReportedNotIgnored() async {
        let log = StubPracticeLog(
            log: PracticeLog(sessions: [session(day: 14, hour: 9)]),
            eraseError: .eraseFailed
        )
        let model = await loaded(log: log)
        await model.confirmReset()
        #expect(model.resetError == .eraseFailed)
        #expect(model.isResetting == false)
    }
}
