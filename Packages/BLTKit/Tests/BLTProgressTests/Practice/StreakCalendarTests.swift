import BLTProgress
import Foundation
import Testing

/// Time zones and daylight saving. The window is real elapsed time; the dates come from the calendar.
struct StreakCalendarTests {
    private typealias Support = PracticeTestSupport

    @Test func travellingChangesWhichDateASessionFallsOn() {
        // 1 Mar 20:00 UTC and 2 Mar 03:00 UTC, seven hours apart.
        let log = PracticeLog(sessions: [
            Support.at(1, 20), Support.at(2, 3)
        ])
        let now = Support.date(2, 4)
        let utc = Support.summary(log, now: now)
        #expect(utc.currentStreak == 2)
        #expect(!utc.goalMet)

        // In Los Angeles (UTC-8 before 8 March) both are on 1 March: one date, and today's two chapters.
        let losAngeles = Support.summary(log, now: now, in: Support.calendar("America/Los_Angeles"))
        #expect(losAngeles.currentStreak == 1)
        #expect(losAngeles.chaptersToday == 2)
        #expect(losAngeles.goalMet)
    }

    @Test func eastwardTravelCanSplitOneDateIntoTwo() {
        // 1 Mar 10:00 and 12:00 UTC: one date in UTC, 23:00 and 01:00 the next day in Auckland (UTC+13).
        let log = PracticeLog(sessions: [Support.at(1, 10), Support.at(1, 12)])
        let auckland = Support.calendar("Pacific/Auckland")
        #expect(Support.summary(log, now: Support.date(1, 12)).currentStreak == 1)
        #expect(Support.summary(log, now: Support.date(1, 12), in: auckland).currentStreak == 2)
    }

    @Test func springForwardMakesSameTimeTomorrowOnly23HoursAwaySoTheStreakHolds() {
        let newYork = Support.calendar("America/New_York")
        let saturday = Support.date(7, 21, in: newYork)
        let sunday = Support.date(8, 21, in: newYork) // the clocks went forward overnight
        #expect(sunday.timeIntervalSince(saturday) == Support.hours(23))
        let log = PracticeLog(sessions: [Support.session(saturday), Support.session(sunday)])
        #expect(Support.summary(log, now: sunday, in: newYork).currentStreak == 2)
    }

    @Test func fallBackMakesSameTimeTomorrow25HoursAwayAndNeedsAFreeze() {
        let newYork = Support.calendar("America/New_York")
        let saturday = Support.date(31, 21, month: 10, in: newYork)
        let sunday = Support.date(1, 21, month: 11, in: newYork) // the clocks went back overnight
        #expect(sunday.timeIntervalSince(saturday) == Support.hours(25))
        let log = PracticeLog(sessions: [Support.session(saturday), Support.session(sunday)])
        let summary = Support.summary(log, now: sunday, in: newYork)
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 1)
    }

    @Test func fallBackIsCoveredWhenAFreezeIsHeld() {
        let newYork = Support.calendar("America/New_York")
        // Seven daily sessions ending Saturday 31 Oct 21:00, then Sunday 1 Nov 21:00 (25 hours later).
        var sessions = (0..<7).map { Support.session(Support.date(25 + $0, 21, month: 10, in: newYork)) }
        sessions.append(Support.session(Support.date(1, 21, month: 11, in: newYork)))
        let summary = Support.summary(PracticeLog(sessions: sessions), now: sessions[7].finishedAt, in: newYork)
        #expect(summary.currentStreak == 8)
        #expect(summary.freezesAvailable == 0)
    }

    @Test func streakDaysFollowTheLocalMidnightNotUTC() {
        // 23:30 and 00:30 local in Tokyo are 15:30 and 15:30 UTC on the same UTC date.
        let tokyo = Support.calendar("Asia/Tokyo")
        let log = PracticeLog(sessions: [
            Support.session(Support.date(1, 23, 30, in: tokyo)), Support.session(Support.date(2, 0, 30, in: tokyo))
        ])
        #expect(Support.summary(log, now: Support.date(2, 1, in: tokyo), in: tokyo).currentStreak == 2)
        #expect(Support.summary(log, now: Support.date(2, 1, in: tokyo), in: Support.utc).currentStreak == 1)
    }

    @Test func practiceDayOrdersAndConvertsToAStartOfDay() {
        let earlier = PracticeDay(year: 2026, month: 2, day: 28)
        let later = PracticeDay(year: 2026, month: 3, day: 1)
        #expect(earlier < later)
        #expect(later.startOfDay(in: Support.utc) == Support.date(1, 0))
    }
}
