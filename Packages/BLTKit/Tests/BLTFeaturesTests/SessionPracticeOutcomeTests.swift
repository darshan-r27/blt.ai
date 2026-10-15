import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// What recording one chapter reports: the streak before and after, goal-just-met, and milestones. Pure
/// logs over an in-memory store; no session is run.
struct SessionPracticeOutcomeTests {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// A chain of `days` consecutive daily sessions ending exactly 24 hours before `now`, so recording a
    /// session at `now` takes the streak from `days` to `days + 1`.
    private func chain(days: Int) -> PracticeLog {
        PracticeLog(sessions: (1...max(days, 1)).reversed().map {
            PracticeSession(finishedAt: now.addingTimeInterval(-Double($0) * day), answered: 10)
        })
    }

    private var oneChapterEarlierToday: PracticeLog {
        PracticeLog(sessions: [PracticeSession(finishedAt: now.addingTimeInterval(-600), answered: 5)])
    }

    private func recorder(over log: PracticeLog) -> PracticeRecorder {
        PracticeRecorder(
            log: InMemoryPracticeLogStore(initial: log),
            calendar: calendar,
            calculator: StreakCalculator(),
            onRecorded: { _ in }
        )
    }

    private func outcome(after log: PracticeLog) async throws -> PracticeOutcome {
        try await recorder(over: log).record(answered: 10, finishedAt: now)
    }

    // MARK: Streak before and after

    @Test func firstEverChapterTakesTheStreakFromZeroToOne() async throws {
        let result = try await outcome(after: .empty)
        #expect(result.previousCount == 0)
        #expect(result.newCount == 1)
        #expect(result.milestoneDays == nil)
        #expect(result.chaptersToday == 1)
    }

    @Test func aSecondChapterTheSameDayLeavesTheStreakAlone() async throws {
        let earlierToday = oneChapterEarlierToday
        let result = try await outcome(after: earlierToday)
        #expect(result.previousCount == 1)
        #expect(result.newCount == 1)
        #expect(result.chaptersToday == 2)
    }

    @Test func aBrokenChainRestartsAtOne() async throws {
        let old = PracticeLog(sessions: [PracticeSession(finishedAt: now.addingTimeInterval(-5 * day), answered: 5)])
        let result = try await outcome(after: old)
        #expect(result.previousCount == 0)
        #expect(result.newCount == 1)
    }

    // MARK: Daily goal

    @Test func theSecondChapterOfTheDayJustMetTheGoal() async throws {
        let earlierToday = oneChapterEarlierToday
        let result = try await outcome(after: earlierToday)
        #expect(result.goalJustMet)
        #expect(result.chaptersToday == 2)
        #expect(result.dailyGoal == 2)
    }

    @Test func theFirstChapterOfTheDayHasNotMetTheGoal() async throws {
        #expect(try await outcome(after: chain(days: 3)).goalJustMet == false)
    }

    @Test func aThirdChapterDoesNotMeetTheGoalAgain() async throws {
        let two = PracticeLog(sessions: [
            PracticeSession(finishedAt: now.addingTimeInterval(-1_200), answered: 5),
            PracticeSession(finishedAt: now.addingTimeInterval(-600), answered: 5)
        ])
        let result = try await outcome(after: two)
        #expect(result.goalJustMet == false)
        #expect(result.chaptersToday == 3)
    }

    // MARK: Milestones

    @Test(arguments: [(6, 7), (29, 30), (49, 50), (99, 100)])
    func crossingAMilestoneReportsIt(previous: Int, milestone: Int) async throws {
        let result = try await outcome(after: chain(days: previous))
        #expect(result.previousCount == previous)
        #expect(result.newCount == milestone)
        #expect(result.milestoneDays == milestone)
    }

    @Test(arguments: [0, 5, 7, 28, 30, 48, 98, 100])
    func otherDaysAreNotMilestones(previous: Int) async throws {
        // 0 means no chain at all (a first chapter); the others sit just before or after a milestone.
        let log = previous == 0 ? PracticeLog.empty : chain(days: previous)
        #expect(try await outcome(after: log).milestoneDays == nil)
    }

    @Test func aMilestoneIsNotReportedAgainByAnotherChapterTheSameDay() async throws {
        let sevenDays = PracticeLog(sessions: chain(days: 6).sessions + oneChapterEarlierToday.sessions)
        // Today already counts, so the streak is 7 before this chapter and stays 7 after it.
        let result = try await outcome(after: sevenDays)
        #expect(result.previousCount == 7)
        #expect(result.newCount == 7)
        #expect(result.milestoneDays == nil)
    }

    // MARK: Freezes

    @Test func theNextFreezeCountdownAndFreezesLeftComeFromTheNewSummary() async throws {
        let result = try await outcome(after: chain(days: 6))
        // Day 7 earns the first freeze; the next is seven days away.
        #expect(result.freezesLeft == 1)
        #expect(result.daysUntilNextFreeze == 7)
    }
}
