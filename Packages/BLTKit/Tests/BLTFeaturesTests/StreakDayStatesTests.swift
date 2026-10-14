import BLTDesign
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

struct StreakDayStatesTests {
    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private func day(_ number: Int) -> PracticeDay {
        PracticeDay(year: 2026, month: 10, day: number)
    }

    private func summary(
        practised: Set<PracticeDay> = [],
        goalMet: Set<PracticeDay> = [],
        frozen: Set<PracticeDay> = []
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
            practisedDays: practised,
            goalMetDays: goalMet,
            frozenDays: frozen
        )
    }

    private func start(_ number: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: number)) ?? .distantPast
    }

    @Test func eachSetMapsToItsState() {
        let calendar = calendar()
        let states = StreakDayStates.states(
            for: summary(practised: [day(1), day(2)], goalMet: [day(2)], frozen: [day(3)]),
            calendar: calendar
        )
        #expect(states[start(1, in: calendar)] == .practised)
        #expect(states[start(2, in: calendar)] == .goalMet)
        #expect(states[start(3, in: calendar)] == .freeze)
        #expect(states[start(4, in: calendar)] == nil)
        #expect(states.count == 3)
    }

    @Test func aDayWithPracticeKeepsThePracticeOverAFreeze() {
        let calendar = calendar()
        let states = StreakDayStates.states(for: summary(practised: [day(5)], frozen: [day(5)]), calendar: calendar)
        #expect(states[start(5, in: calendar)] == .practised)
    }

    @Test func theGoalOutranksPlainPractice() {
        let calendar = calendar()
        let states = StreakDayStates.states(
            for: summary(practised: [day(6)], goalMet: [day(6)], frozen: [day(6)]),
            calendar: calendar
        )
        #expect(states[start(6, in: calendar)] == .goalMet)
    }

    @Test func keysAreTheStartOfDayInTheGivenCalendar() {
        let tokyo = calendar("Asia/Tokyo")
        let states = StreakDayStates.states(for: summary(practised: [day(9)]), calendar: tokyo)
        let key = states.keys.first
        #expect(key == tokyo.startOfDay(for: start(9, in: tokyo)))
        #expect(key.map { tokyo.component(.hour, from: $0) } == 0)
    }

    @Test func noDaysMeansNoStates() {
        #expect(StreakDayStates.states(for: .empty(), calendar: calendar()).isEmpty)
    }

    @Test func aRealSummaryMapsEndToEnd() {
        let calendar = calendar()
        let noon = start(14, in: calendar).addingTimeInterval(12 * 3_600)
        let log = PracticeLog(sessions: [
            PracticeSession(finishedAt: noon.addingTimeInterval(-86_400), answered: 5),
            PracticeSession(finishedAt: noon.addingTimeInterval(-600), answered: 5),
            PracticeSession(finishedAt: noon, answered: 5)
        ])
        let states = StreakDayStates.states(
            for: StreakCalculator().summary(for: log, now: noon, calendar: calendar),
            calendar: calendar
        )
        #expect(states[start(13, in: calendar)] == .practised)
        #expect(states[start(14, in: calendar)] == .goalMet)
    }
}
