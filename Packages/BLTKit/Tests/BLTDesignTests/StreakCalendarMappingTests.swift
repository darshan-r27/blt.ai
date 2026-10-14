import BLTDesign
import Foundation
import Testing

/// The week and month day-state mapping helpers (pure, with an injected calendar).
struct StreakCalendarMappingTests {
    private func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        TestCalendar.date(year: year, month: month, day: day)
    }

    // MARK: Week

    @Test func mondayFirstWeekContainingAWednesday() {
        let dates = StreakWeek.dates(containing: date(10, 14), calendar: TestCalendar.monday)
        #expect(dates == (12...18).map { date(10, $0) })
    }

    @Test func sundayFirstWeekContainingAWednesday() {
        let dates = StreakWeek.dates(containing: date(10, 14), calendar: TestCalendar.sunday)
        #expect(dates == (11...17).map { date(10, $0) })
    }

    @Test func aWeekCanCrossAMonthBoundary() {
        // Thursday 1 October 2026: the Monday-first week starts on Monday 28 September.
        let dates = StreakWeek.dates(containing: date(10, 1), calendar: TestCalendar.monday)
        #expect(dates.first == date(9, 28))
        #expect(dates.last == date(10, 4))
        #expect(dates.count == 7)
    }

    @Test func aTimeLaterInTheDayStillGivesStartsOfDay() {
        let evening = date(10, 14).addingTimeInterval(20 * 3600)
        let dates = StreakWeek.dates(containing: evening, calendar: TestCalendar.monday)
        #expect(dates.first == date(10, 12))
    }

    @Test func weekDaysTakeTheirStateOrDefaultToEmpty() {
        let states: [Date: StreakDayState] = [
            date(10, 12): .practised,
            date(10, 13): .goalMet,
            date(10, 15): .freeze,
            date(10, 20): .practised // outside this week: ignored
        ]
        let days = StreakWeek.days(containing: date(10, 14), states: states, calendar: TestCalendar.monday)
        #expect(days.map(\.state) == [.practised, .goalMet, .empty, .freeze, .empty, .empty, .empty])
        #expect(days.map(\.date) == (12...18).map { date(10, $0) })
    }

    @Test func futureMeansALaterCalendarDay() {
        let today = date(10, 14).addingTimeInterval(23 * 3600)
        #expect(StreakWeek.isFuture(date(10, 15), today: today, calendar: TestCalendar.monday))
        #expect(!StreakWeek.isFuture(date(10, 14), today: today, calendar: TestCalendar.monday))
        #expect(!StreakWeek.isFuture(date(10, 13), today: today, calendar: TestCalendar.monday))
    }

    @Test func onlyFlameStatesShowAFlame() {
        #expect(StreakDayState.practised.showsFlame)
        #expect(StreakDayState.goalMet.showsFlame)
        #expect(!StreakDayState.empty.showsFlame)
        #expect(!StreakDayState.freeze.showsFlame)
    }

    // MARK: Month

    @Test func octoberStartsOnAThursday() {
        // 1 October 2026 is a Thursday: 4 blanks when Sunday is first, 3 when Monday is first.
        let sunday = MonthGrid(month: date(10, 14), calendar: TestCalendar.sunday)
        let monday = MonthGrid(month: date(10, 14), calendar: TestCalendar.monday)
        #expect(sunday.rows.first?.prefix(5).map(\.day) == [nil, nil, nil, nil, 1])
        #expect(monday.rows.first?.prefix(4).map(\.day) == [nil, nil, nil, 1])
    }

    @Test func everyRowHasSevenCellsAndEveryDayAppearsOnce() {
        for calendar in [TestCalendar.sunday, TestCalendar.monday] {
            let grid = MonthGrid(month: date(10, 14), calendar: calendar)
            #expect(grid.rows.allSatisfy { $0.count == 7 })
            #expect(grid.rows.flatMap { $0 }.compactMap(\.day) == Array(1...31))
            let ids = grid.rows.flatMap { $0 }.map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test func dayCellsCarryTheStartOfThatDay() {
        let grid = MonthGrid(month: date(10, 14), calendar: TestCalendar.monday)
        let cells = grid.rows.flatMap { $0 }.filter { $0.day != nil }
        #expect(cells.map(\.date) == (1...31).map { date(10, $0) })
    }

    @Test func aMonthThatFillsWholeWeeksHasNoBlanks() {
        // February 2026 starts on a Sunday and has 28 days.
        let grid = MonthGrid(month: date(2, 10), calendar: TestCalendar.sunday)
        #expect(grid.rows.count == 4)
        #expect(grid.rows.flatMap { $0 }.allSatisfy { $0.day != nil })
        // Monday first: 6 leading blanks push it to five rows.
        #expect(MonthGrid(month: date(2, 10), calendar: TestCalendar.monday).rows.count == 5)
    }

    @Test func leapYearFebruaryHasTwentyNineDays() {
        let grid = MonthGrid(month: date(2, 1, year: 2028), calendar: TestCalendar.monday)
        #expect(grid.rows.flatMap { $0 }.compactMap(\.day).last == 29)
    }

    @Test func weekdayHeadersStartOnTheFirstWeekday() {
        #expect(MonthGrid.weekdayHeaders(calendar: TestCalendar.sunday) == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(MonthGrid.weekdayHeaders(calendar: TestCalendar.monday) == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func summaryCountsOnlyDaysInThatMonth() {
        let states: [Date: StreakDayState] = [
            date(10, 1): .practised,
            date(10, 2): .goalMet,
            date(10, 3): .goalMet,
            date(10, 4): .freeze,
            date(9, 30): .practised, // another month
            date(11, 1): .goalMet // another month
        ]
        let summary = MonthGrid(month: date(10, 14), calendar: TestCalendar.monday).summary(states: states)
        #expect(summary == MonthGrid.Summary(practisedDays: 3, goalDays: 2, freezeDays: 1))
    }

    @Test func emptyMonthSummaryIsAllZero() {
        let summary = MonthGrid(month: date(10, 14), calendar: TestCalendar.monday).summary(states: [:])
        #expect(summary == MonthGrid.Summary(practisedDays: 0, goalDays: 0, freezeDays: 0))
    }
}
