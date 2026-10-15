import BLTProgress
import Foundation
import Testing

/// The streak number, the 24-hour window, the daily goal and the deadline.
struct StreakCalculatorTests {
    private typealias Support = PracticeTestSupport

    @Test func emptyLogIsAllZero() {
        let summary = Support.summary(.empty, now: Support.date(5, 9))
        #expect(summary == .empty())
        #expect(summary.currentStreak == 0)
        #expect(summary.deadline == nil)
        #expect(!summary.practisedToday)
    }

    @Test func oneSessionIsADayOfStreak() {
        let log = PracticeLog(sessions: [Support.at(1, 9)])
        let summary = Support.summary(log, now: Support.date(1, 10))
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 1)
        #expect(summary.practisedToday)
        #expect(summary.chaptersToday == 1)
        #expect(!summary.goalMet)
    }

    // MARK: Window and the number

    @Test func practisingEvery23HoursCountsOneDayPerDate() {
        // 1 Mar 00:30, 1 Mar 23:30, 2 Mar 22:30, 3 Mar 21:30, 4 Mar 20:30: five sessions, four dates.
        let start = Support.date(1, 0, 30)
        let log = PracticeLog(sessions: (0..<5).map { Support.session(start + Support.hours(23 * Double($0))) })
        let summary = Support.summary(log, now: start + Support.hours(23 * 4))
        #expect(summary.currentStreak == 4)
        #expect(summary.practisedDays.count == 4)
    }

    @Test func gapOfExactly24HoursKeepsTheStreak() {
        let log = PracticeLog(sessions: [
            Support.at(1, 9), Support.at(2, 9)
        ])
        #expect(Support.summary(log, now: Support.date(2, 9)).currentStreak == 2)
    }

    @Test func midnightCrossingTwentyMinutesApartIsTwoDates() {
        let log = PracticeLog(sessions: [
            Support.at(1, 23, 50), Support.at(2, 0, 10)
        ])
        let summary = Support.summary(log, now: Support.date(2, 0, 20))
        #expect(summary.currentStreak == 2)
        #expect(summary.chaptersToday == 1)
    }

    @Test func twoSessionsOnOneDateAreOneStreakDay() {
        let log = PracticeLog(sessions: [
            Support.at(1, 8), Support.at(1, 20)
        ])
        #expect(Support.summary(log, now: Support.date(1, 21)).currentStreak == 1)
    }

    @Test func logIsOrderedByFinishTimeWhateverTheInsertionOrder() {
        let log = PracticeLog(sessions: [
            Support.at(3, 9), Support.at(1, 9), Support.at(2, 9)
        ])
        #expect(log.sessions.map(\.finishedAt) == [Support.date(1, 9), Support.date(2, 9), Support.date(3, 9)])
        #expect(Support.summary(log, now: Support.date(3, 10)).currentStreak == 3)
    }

    // MARK: Gaps with and without a freeze

    @Test func gapOf25HoursWithoutFreezeResetsButKeepsLongest() {
        let log = PracticeLog(sessions: [
            Support.at(1, 9), Support.at(2, 9), Support.at(3, 9),
            Support.at(4, 10)
        ])
        let summary = Support.summary(log, now: Support.date(4, 10))
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 3)
        #expect(summary.freezesAvailable == 0)
    }

    @Test func gapOf25HoursWithAFreezeKeepsTheChainAndUsesIt() {
        var sessions = Support.dailyLog(days: 7).sessions // seventh date earns the first freeze
        sessions.append(Support.at(8, 10)) // 25 hours after 7 Mar 09:00
        let summary = Support.summary(PracticeLog(sessions: sessions), now: Support.date(8, 10))
        #expect(summary.currentStreak == 8)
        #expect(summary.freezesAvailable == 0)
        // The covered window ended at 8 Mar 09:00.
        #expect(summary.frozenDays == [PracticeDay(year: 2026, month: 3, day: 8)])
    }

    @Test func aFreezeCoversOneWindowOnly() {
        // One freeze held; the next session is 49 hours later, two windows missed.
        var sessions = Support.dailyLog(days: 7).sessions
        sessions.append(Support.at(9, 10))
        let summary = Support.summary(PracticeLog(sessions: sessions), now: Support.date(9, 10))
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 7)
        #expect(summary.freezesAvailable == 1) // not spent on a chain that broke anyway
    }

    @Test func twoFreezesCoverTwoMissedWindows() {
        var sessions = Support.dailyLog(days: 14).sessions
        sessions.append(Support.at(16, 10)) // 49 hours after 14 Mar 09:00
        let summary = Support.summary(PracticeLog(sessions: sessions), now: Support.date(16, 10))
        #expect(summary.currentStreak == 15)
        #expect(summary.freezesAvailable == 0)
        #expect(summary.frozenDays == [
            PracticeDay(year: 2026, month: 3, day: 15), PracticeDay(year: 2026, month: 3, day: 16)
        ])
    }

    @Test func gapOfExactly48HoursNeedsOneFreeze() {
        var sessions = Support.dailyLog(days: 7).sessions
        sessions.append(Support.at(9, 9))
        let summary = Support.summary(PracticeLog(sessions: sessions), now: Support.date(9, 9))
        #expect(summary.currentStreak == 8)
        #expect(summary.freezesAvailable == 0)
    }

    // MARK: Earning freezes

    @Test func freezeIsEarnedAtSevenDaysAndNotBefore() {
        let six = Support.summary(Support.dailyLog(days: 6), now: Support.date(6, 10))
        #expect(six.freezesAvailable == 0)
        #expect(six.daysUntilNextFreeze == 1)
        let seven = Support.summary(Support.dailyLog(days: 7), now: Support.date(7, 10))
        #expect(seven.freezesAvailable == 1)
        #expect(seven.daysUntilNextFreeze == 7)
    }

    @Test func secondFreezeAtFourteenAndTheCapIsTwo() {
        let fourteen = Support.summary(Support.dailyLog(days: 14), now: Support.date(14, 10))
        #expect(fourteen.freezesAvailable == 2)
        #expect(fourteen.daysUntilNextFreeze == nil)
        let twentyOne = Support.summary(Support.dailyLog(days: 21), now: Support.date(21, 10))
        #expect(twentyOne.freezesAvailable == 2)
        #expect(twentyOne.currentStreak == 21)
    }

    @Test func extraSessionsOnTheSameDateEarnNothing() {
        var sessions = Support.dailyLog(days: 6).sessions
        sessions.append(Support.at(6, 20))
        sessions.append(Support.at(6, 21))
        #expect(Support.summary(PracticeLog(sessions: sessions), now: Support.date(6, 22)).freezesAvailable == 0)
    }

    @Test func resetKeepsLongestAndAChainStartsAgainAtOne() {
        var sessions = Support.dailyLog(days: 5).sessions // no freeze
        sessions.append(Support.at(10, 9))
        let summary = Support.summary(PracticeLog(sessions: sessions), now: Support.date(10, 10))
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 5)
        #expect(summary.daysUntilNextFreeze == 6)
    }

    // MARK: Now (read time, no new session)

    @Test func streakIsAliveWithinTheWindowAndDeadlineIsLastPlus24Hours() {
        let summary = Support.summary(Support.dailyLog(days: 3), now: Support.date(3, 14))
        #expect(summary.currentStreak == 3)
        #expect(summary.deadline == StreakDeadline(practiseBy: Support.date(4, 9), freezeWouldCover: false))
        #expect(!summary.goalMet)
    }

    @Test func aWindowMissedWithAFreezeSpendsItInTheSummary() {
        let log = Support.dailyLog(days: 7)
        let summary = Support.summary(log, now: Support.date(8, 12)) // 27 hours after the last session
        #expect(summary.currentStreak == 7)
        #expect(summary.freezesAvailable == 0)
        #expect(summary.deadline == StreakDeadline(practiseBy: Support.date(9, 9), freezeWouldCover: false))
        #expect(summary.frozenDays == [PracticeDay(year: 2026, month: 3, day: 8)])
        #expect(summary.chaptersToday == 0)
        #expect(!summary.practisedToday)
    }

    @Test func deadlineReportsWhenAFreezeWouldCover() {
        let summary = Support.summary(Support.dailyLog(days: 7), now: Support.date(7, 12))
        #expect(summary.deadline == StreakDeadline(practiseBy: Support.date(8, 9), freezeWouldCover: true))
    }

    @Test func streakBreaksAtReadTimeWhenNothingCoversTheGap() {
        let summary = Support.summary(Support.dailyLog(days: 3), now: Support.date(5, 10)) // 49 hours
        #expect(summary.currentStreak == 0)
        #expect(summary.longestStreak == 3)
        #expect(summary.deadline == nil)
        #expect(Support.summary(Support.dailyLog(days: 3), now: Support.date(4, 10)).currentStreak == 0) // 25 hours
    }

    @Test func aLongLapseWithFreezesStillBreaksAndKeepsTheFreezes() {
        let summary = Support.summary(Support.dailyLog(days: 14), now: Support.date(25, 9))
        #expect(summary.currentStreak == 0)
        #expect(summary.longestStreak == 14)
        #expect(summary.freezesAvailable == 2)
    }

    // MARK: Daily goal

    @Test func goalIsMetOnTheSecondSessionOfADate() {
        let one = PracticeLog(sessions: [Support.at(1, 8)])
        #expect(!Support.summary(one, now: Support.date(1, 9)).goalMet)
        let two = one.appending(Support.at(1, 18))
        let summary = Support.summary(two, now: Support.date(1, 19))
        #expect(summary.goalMet)
        #expect(summary.chaptersToday == 2)
        #expect(summary.goalDays == 1)
        #expect(summary.goalMetDays == [PracticeDay(year: 2026, month: 3, day: 1)])
    }

    @Test func goalDaysCountsDatesNotSessionsAndFollowsTheConfiguredGoal() {
        let log = PracticeLog(sessions: [
            Support.at(1, 8), Support.at(1, 9), Support.at(1, 10),
            Support.at(2, 8)
        ])
        #expect(Support.summary(log, now: Support.date(2, 9)).goalDays == 1)
        #expect(Support.summary(log, now: Support.date(2, 9), goal: 3).goalDays == 1)
        #expect(Support.summary(log, now: Support.date(2, 9), goal: 1).goalDays == 2)
    }

    @Test func zeroAnswerSessionsAreIgnoredByTheCalculator() {
        let log = PracticeLog(sessions: [
            Support.at(1, 9, answered: 0), Support.at(1, 10, answered: 0)
        ])
        #expect(Support.summary(log, now: Support.date(1, 11)) == .empty())
        let mixed = PracticeLog(sessions: [
            Support.at(1, 9), Support.at(1, 10, answered: 0)
        ])
        #expect(Support.summary(mixed, now: Support.date(1, 11)).chaptersToday == 1)
    }

    @Test func appendingAZeroAnswerSessionLeavesTheLogUnchanged() {
        let log = PracticeLog(sessions: [Support.at(1, 9)])
        #expect(log.appending(Support.at(1, 10, answered: 0)) == log)
    }
}
