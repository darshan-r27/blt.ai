import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

/// Collects what `onSessionRecorded` was called with.
private actor RecordedSummaries {
    private(set) var summaries: [StreakSummary] = []
    func add(_ summary: StreakSummary) { summaries.append(summary) }
}

/// A practice log whose reads or writes fail, to check that a failure never costs the learner anything.
private actor FailingPracticeLogStore: PracticeLogStore {
    enum Failure { case write, read }

    private let failure: Failure
    private(set) var erased = false

    init(_ failure: Failure) { self.failure = failure }

    func load() async throws(PracticeLogError) -> PracticeLog {
        if failure == .read { throw .corrupt }
        return .empty
    }

    func append(_ session: PracticeSession) async throws(PracticeLogError) {
        throw .writeFailed
    }

    func erase() async throws(PracticeLogError) {
        erased = true
    }
}

/// When a chapter is recorded in the practice log: at the summary, on an early end with answers, never
/// twice, never for a session with no answers, and without harm when the log fails.
@MainActor
struct SessionPracticeRecordingTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func makeModel(
        progress: some ProgressStore = InMemoryProgressStore(),
        log: some PracticeLogStore,
        recorded: RecordedSummaries = RecordedSummaries()
    ) -> SessionViewModel {
        let fixedNow = now
        return SessionViewModel(
            scenario: PreviewCatalog.scenario,
            dependencies: AppDependencies(
                catalog: PreviewCatalog.catalog,
                language: .tamil,
                store: progress,
                scheduler: SM2Scheduler(),
                now: { fixedNow }
            ),
            random: .seeded(3),
            practiceLog: log,
            calendar: calendar,
            onSessionRecorded: { await recorded.add($0) }
        )
    }

    private func answerCorrectly(_ model: SessionViewModel) throws {
        guard case .session(.asking(let question)) = model.screen else { throw RecordingTestError.notAsking }
        model.choose(try #require(question.options.first { $0.kind == .canonical }).id)
    }

    /// Answers every question correctly and presses Continue until the summary shows.
    private func finish(_ model: SessionViewModel) throws {
        for _ in 0..<2 {
            try answerCorrectly(model)
            model.advance()
        }
        guard case .session(.finished) = model.screen else { throw RecordingTestError.notFinished }
    }

    // MARK: Counting

    @Test func reachingTheSummaryRecordsOneChapter() async throws {
        let log = InMemoryPracticeLogStore()
        let recorded = RecordedSummaries()
        let model = makeModel(log: log, recorded: recorded)
        await model.start()
        try finish(model)
        await model.waitForPendingSaves()

        let sessions = try await log.load().sessions
        #expect(sessions == [PracticeSession(finishedAt: now, answered: 2)])
        guard case .recorded(let outcome) = model.practiceState else {
            Issue.record("expected a recorded outcome")
            return
        }
        #expect(outcome.previousCount == 0)
        #expect(outcome.newCount == 1)
        #expect(await recorded.summaries.count == 1)
        #expect(await recorded.summaries.first?.currentStreak == 1)
    }

    @Test func endingEarlyWithAnAnswerRecordsAChapter() async throws {
        let log = InMemoryPracticeLogStore()
        let recorded = RecordedSummaries()
        let model = makeModel(log: log, recorded: recorded)
        await model.start()
        try answerCorrectly(model)
        await model.endSession()

        #expect(try await log.load().sessions == [PracticeSession(finishedAt: now, answered: 1)])
        #expect(await recorded.summaries.count == 1)
    }

    @Test func endingWithoutAnAnswerRecordsNothing() async throws {
        let log = InMemoryPracticeLogStore()
        let recorded = RecordedSummaries()
        let model = makeModel(log: log, recorded: recorded)
        await model.start()
        await model.endSession()

        #expect(try await log.load().sessions.isEmpty)
        #expect(model.practiceState == .none)
        #expect(await recorded.summaries.isEmpty)
    }

    @Test func leavingFromTheSummaryDoesNotRecordASecondTime() async throws {
        let log = InMemoryPracticeLogStore()
        let recorded = RecordedSummaries()
        let model = makeModel(log: log, recorded: recorded)
        await model.start()
        try finish(model)
        await model.endSession()
        await model.endSession()
        model.advance()

        #expect(try await log.load().sessions.count == 1)
        #expect(await recorded.summaries.count == 1)
    }

    @Test func aRepeatedAdvanceOnTheSummaryDoesNotRecordASecondTime() async throws {
        let log = InMemoryPracticeLogStore()
        let model = makeModel(log: log)
        await model.start()
        try finish(model)
        model.advance()
        model.advance()
        await model.waitForPendingSaves()

        #expect(try await log.load().sessions.count == 1)
    }

    @Test func theSecondChapterOfTheDayReportsTheGoalMet() async throws {
        let earlier = PracticeSession(finishedAt: now.addingTimeInterval(-3_600), answered: 4)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [earlier]))
        let model = makeModel(log: log)
        await model.start()
        try finish(model)
        await model.waitForPendingSaves()

        guard case .recorded(let outcome) = model.practiceState else {
            Issue.record("expected a recorded outcome")
            return
        }
        #expect(outcome.goalJustMet)
        #expect(outcome.chaptersToday == 2)
        #expect(outcome.previousCount == outcome.newCount)
    }

    // MARK: Failure

    @Test func aLogWriteFailureIsShownAndKeepsTheAnswersAndTheSummary() async throws {
        let progress = InMemoryProgressStore()
        let log = FailingPracticeLogStore(.write)
        let recorded = RecordedSummaries()
        let model = makeModel(progress: progress, log: log, recorded: recorded)
        await model.start()
        try finish(model)
        await model.waitForPendingSaves()

        #expect(model.practiceState == .failed)
        guard case .session(.finished(let result)) = model.screen else {
            Issue.record("the summary must still show")
            return
        }
        #expect(result.total == 2)
        #expect(model.saveFailed == false)
        #expect(try await progress.load().attempts.count == 2)
        #expect(await recorded.summaries.isEmpty)
        #expect(await log.erased == false)
    }

    @Test func anUnreadableLogIsShownAndNeverErased() async throws {
        let progress = InMemoryProgressStore()
        let log = FailingPracticeLogStore(.read)
        let model = makeModel(progress: progress, log: log)
        await model.start()
        try finish(model)
        await model.endSession()

        #expect(model.practiceState == .failed)
        #expect(try await progress.load().attempts.count == 2)
        #expect(await log.erased == false)
    }

    @Test func aFailureOnAnEarlyEndStillLeavesAndKeepsTheAnswer() async throws {
        let progress = InMemoryProgressStore()
        let model = makeModel(progress: progress, log: FailingPracticeLogStore(.write))
        var left = 0
        await model.start()
        model.setDoneHandler { left += 1 }
        try answerCorrectly(model)
        await model.endSession()

        #expect(left == 1)
        #expect(try await progress.load().attempts.count == 1)
    }
}

private enum RecordingTestError: Error {
    case notAsking
    case notFinished
}
