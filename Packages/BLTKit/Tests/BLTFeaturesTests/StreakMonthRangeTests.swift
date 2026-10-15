import Foundation
import Testing

@testable import BLTFeatures

struct StreakMonthRangeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func range(firstPractised: Date?, now: Date) -> StreakMonthRange {
        StreakMonthRange(firstPractised: firstPractised, now: now, calendar: calendar)
    }

    @Test func theRangeRunsFromTheFirstPractisedMonthToTheCurrentOne() {
        let range = range(firstPractised: date(2026, 8, 20), now: date(2026, 10, 14))
        #expect(range.first == date(2026, 8))
        #expect(range.last == date(2026, 10))
    }

    @Test func withNoPracticeOnlyTheCurrentMonthIsAllowed() {
        let range = range(firstPractised: nil, now: date(2026, 10, 14))
        #expect(range.first == date(2026, 10))
        #expect(!range.canGoPrevious(from: date(2026, 10)))
        #expect(!range.canGoNext(from: date(2026, 10)))
    }

    @Test func pagingBackStopsAtTheFirstMonth() {
        let range = range(firstPractised: date(2026, 8, 20), now: date(2026, 10, 14))
        let september = range.previous(from: date(2026, 10))
        #expect(september == date(2026, 9))
        let august = range.previous(from: september)
        #expect(august == date(2026, 8))
        #expect(!range.canGoPrevious(from: august))
        #expect(range.previous(from: august) == date(2026, 8))
    }

    @Test func pagingForwardStopsAtTheCurrentMonth() {
        let range = range(firstPractised: date(2026, 8, 20), now: date(2026, 10, 14))
        #expect(range.canGoNext(from: date(2026, 9)))
        #expect(range.next(from: date(2026, 9)) == date(2026, 10))
        #expect(!range.canGoNext(from: date(2026, 10)))
        #expect(range.next(from: date(2026, 10)) == date(2026, 10))
    }

    @Test func pagingCrossesAYearBoundary() {
        let range = range(firstPractised: date(2025, 11, 3), now: date(2026, 1, 5))
        #expect(range.previous(from: date(2026, 1)) == date(2025, 12))
        #expect(range.previous(from: date(2025, 12)) == date(2025, 11))
        #expect(!range.canGoPrevious(from: date(2025, 11)))
    }

    @Test func aFirstMonthInTheFutureIsClampedToNow() {
        let range = range(firstPractised: date(2027, 3, 1), now: date(2026, 10, 14))
        #expect(range.first == date(2026, 10))
    }

    @Test func clampedPullsAnyMonthIntoTheRange() {
        let range = range(firstPractised: date(2026, 8, 20), now: date(2026, 10, 14))
        #expect(range.clamped(date(2026, 1, 15)) == date(2026, 8))
        #expect(range.clamped(date(2027, 1, 15)) == date(2026, 10))
        #expect(range.clamped(date(2026, 9, 15)) == date(2026, 9))
    }
}
