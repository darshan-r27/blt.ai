import BLTDesign
import Foundation
import Testing

struct StreakLabelsTests {
    @Test func streakLabelNamesTheDaysAndFreezes() {
        #expect(StreakLabels.streak(count: 13, freezesLeft: 1) == "13 day streak, 1 freeze left")
        #expect(StreakLabels.streak(count: 13, freezesLeft: 2) == "13 day streak, 2 freezes left")
        #expect(StreakLabels.streak(count: 13, freezesLeft: 0) == "13 day streak, no freezes left")
        #expect(StreakLabels.streak(count: 13) == "13 day streak")
        #expect(StreakLabels.streak(count: 1) == "1 day streak")
    }

    @Test func aZeroStreakIsSaidCalmly() {
        #expect(StreakLabels.streak(count: 0) == "No streak yet")
        #expect(StreakLabels.streak(count: 0, freezesLeft: 2) == "No streak yet, 2 freezes left")
    }

    @Test func negativeNumbersAreClampedToZero() {
        #expect(StreakLabels.streak(count: -4, freezesLeft: -1) == "No streak yet, no freezes left")
        #expect(StreakLabels.freezes(-3) == "no freezes")
    }

    @Test func freezePluralisation() {
        #expect(StreakLabels.freezes(0) == "no freezes")
        #expect(StreakLabels.freezes(1) == "1 freeze")
        #expect(StreakLabels.freezes(2) == "2 freezes")
    }

    @Test func todayLabelShowsProgressAndGoalMet() {
        #expect(StreakLabels.today(chaptersDone: 1, goal: 2) == "Today: 1 of 2 chapters")
        #expect(StreakLabels.today(chaptersDone: 0, goal: 2) == "Today: 0 of 2 chapters")
        #expect(StreakLabels.today(chaptersDone: 2, goal: 2) == "Today: 2 of 2 chapters, daily goal met")
        #expect(StreakLabels.today(chaptersDone: 0, goal: 1) == "Today: 0 of 1 chapter")
    }

    @Test func todayLabelClampsOddInputs() {
        #expect(StreakLabels.today(chaptersDone: 5, goal: 2) == "Today: 2 of 2 chapters, daily goal met")
        #expect(StreakLabels.today(chaptersDone: -1, goal: 0) == "Today: 0 of 1 chapter")
    }

    @Test func milestoneLabel() {
        #expect(StreakLabels.milestone(days: 7) == "7 day milestone")
        #expect(StreakLabels.milestone(days: 100) == "100 day milestone")
    }

    @Test func stateWords() {
        #expect(StreakLabels.state(.empty) == "no practice")
        #expect(StreakLabels.state(.practised) == "practised, streak day")
        #expect(StreakLabels.state(.goalMet) == "practised, daily goal met")
        #expect(StreakLabels.state(.freeze) == "streak freeze used")
        #expect(StreakLabels.state(.goalMet, isFuture: true) == "upcoming")
    }

    @Test func everyStateHasADistinctLabel() {
        let words = StreakDayState.allCases.map { StreakLabels.state($0) }
        #expect(Set(words).count == words.count)
    }

    // MARK: Dates (en_US, Gregorian, UTC; Wednesday 14 October 2026 is "today")

    private func date(_ day: Int) -> Date {
        TestCalendar.date(year: 2026, month: 10, day: day)
    }

    @Test func dayLabelForAPastToTodayAndFutureDay() {
        let calendar = TestCalendar.monday
        let today = date(14)
        func label(_ day: Int, _ state: StreakDayState) -> String {
            StreakLabels.day(
                date: date(day), state: state, today: today, calendar: calendar, locale: TestCalendar.locale
            )
        }
        #expect(label(13, .practised) == "Tuesday, October 13, practised, streak day")
        #expect(label(12, .goalMet) == "Monday, October 12, practised, daily goal met")
        #expect(label(11, .freeze) == "Sunday, October 11, streak freeze used")
        #expect(label(10, .empty) == "Saturday, October 10, no practice")
        #expect(label(14, .empty) == "Wednesday, October 14, today, no practice")
        #expect(label(14, .goalMet) == "Wednesday, October 14, today, practised, daily goal met")
        #expect(label(15, .empty) == "Thursday, October 15, upcoming")
    }

    @Test func monthTitle() {
        let title = StreakLabels.monthTitle(date(14), calendar: TestCalendar.monday, locale: TestCalendar.locale)
        #expect(title == "October 2026")
    }

    @Test func monthSummaryWords() {
        let none = MonthGrid.Summary(practisedDays: 0, goalDays: 0, freezeDays: 0)
        let one = MonthGrid.Summary(practisedDays: 1, goalDays: 0, freezeDays: 0)
        let all = MonthGrid.Summary(practisedDays: 12, goalDays: 3, freezeDays: 1)
        #expect(StreakLabels.monthSummary(none) == "0 practice days")
        #expect(StreakLabels.monthSummary(one) == "1 practice day")
        #expect(StreakLabels.monthSummary(all) == "12 practice days, 3 with the daily goal met, 1 freeze used")
    }
}
