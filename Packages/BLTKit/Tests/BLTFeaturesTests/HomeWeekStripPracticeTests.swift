import BLTDesign
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

// The mapping from a streak summary to the seven days of Home's week strip. Pure, fake dates only.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    calendar.firstWeekday = 2
    return calendar
}()

/// Wednesday 14 October 2026, so the week runs Monday 12 to Sunday 18.
private func moment(day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
}

private func practiceDay(_ day: Int) -> PracticeDay {
    PracticeDay(year: 2026, month: 10, day: day)
}

private func summary(
    practised: Set<Int> = [],
    goalMet: Set<Int> = [],
    frozen: Set<Int> = []
) -> StreakSummary {
    StreakSummary(
        currentStreak: 0,
        longestStreak: 0,
        freezesAvailable: 0,
        daysUntilNextFreeze: nil,
        chaptersToday: 0,
        dailyGoal: 2,
        goalDays: goalMet.count,
        lastSessionAt: nil,
        deadline: nil,
        practisedDays: Set((practised.union(goalMet)).map(practiceDay)),
        goalMetDays: Set(goalMet.map(practiceDay)),
        frozenDays: Set(frozen.map(practiceDay))
    )
}

struct HomeWeekStripPracticeTests {
    @Test func theStripHasTheSevenDaysOfTheWeekContainingToday() {
        let days = HomeWeekDays.days(for: .empty(), now: moment(day: 14), calendar: calendar)
        #expect(days.count == 7)
        let numbers = days.map { calendar.component(.day, from: $0.date) }
        #expect(numbers == [12, 13, 14, 15, 16, 17, 18])
    }

    @Test func aWeekWithNoPracticeIsAllEmpty() {
        let days = HomeWeekDays.days(for: .empty(), now: moment(day: 14), calendar: calendar)
        #expect(days.allSatisfy { $0.state == .empty })
    }

    @Test func practisedGoalMetAndFreezeDaysGetTheirMarks() {
        let days = HomeWeekDays.days(
            for: summary(practised: [14], goalMet: [13], frozen: [12]),
            now: moment(day: 14),
            calendar: calendar
        )
        #expect(days.map(\.state) == [.freeze, .goalMet, .practised, .empty, .empty, .empty, .empty])
    }

    @Test func goalMetBeatsPractisedAndPractisedBeatsFreeze() {
        let days = HomeWeekDays.days(
            for: summary(practised: [12, 13], goalMet: [13], frozen: [12, 13]),
            now: moment(day: 14),
            calendar: calendar
        )
        #expect(days[0].state == .practised)
        #expect(days[1].state == .goalMet)
    }

    @Test func daysStillToComeAreEmptyWhateverTheSummarySays() {
        let days = HomeWeekDays.days(
            for: summary(practised: [15], goalMet: [16], frozen: [17]),
            now: moment(day: 14),
            calendar: calendar
        )
        #expect(days[3...].allSatisfy { $0.state == .empty })
    }

    @Test func daysBeforeThisWeekAreNotShown() {
        let days = HomeWeekDays.days(for: summary(practised: [11, 10]), now: moment(day: 14), calendar: calendar)
        #expect(days.allSatisfy { $0.state == .empty })
    }

    @Test func aMondayFirstWeekStartsOnMondayEvenWhenTodayIsSunday() {
        let days = HomeWeekDays.days(for: summary(practised: [18]), now: moment(day: 18), calendar: calendar)
        #expect(calendar.component(.day, from: days[0].date) == 12)
        #expect(days[6].state == .practised)
    }

    @Test func aRealLogMapsThroughTheCalculator() {
        let log = PracticeLog(sessions: [
            PracticeSession(finishedAt: moment(day: 12, hour: 18), answered: 10),
            PracticeSession(finishedAt: moment(day: 13, hour: 9), answered: 10),
            PracticeSession(finishedAt: moment(day: 13, hour: 10), answered: 10),
            PracticeSession(finishedAt: moment(day: 14, hour: 9), answered: 10)
        ])
        let now = moment(day: 14)
        let streak = StreakCalculator().summary(for: log, now: now, calendar: calendar)
        let days = HomeWeekDays.days(for: streak, now: now, calendar: calendar)
        #expect(days.map(\.state) == [.practised, .goalMet, .practised, .empty, .empty, .empty, .empty])
    }
}
