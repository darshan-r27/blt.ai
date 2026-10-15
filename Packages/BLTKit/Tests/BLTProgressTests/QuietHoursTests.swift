import BLTProgress
import Foundation
import Testing

struct QuietHoursTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(
            calendar: utc, timeZone: utc.timeZone, year: 2026, month: 6, day: day, hour: hour, minute: minute
        )
        return parts.date ?? .distantPast
    }

    @Test func standardWindowIsTenPmToEightAm() {
        #expect(QuietHours.standard.startMinute == 22 * 60)
        #expect(QuietHours.standard.endMinute == 8 * 60)
        #expect(QuietHours.standard.spansMidnight)
    }

    @Test(arguments: [
        (1319, false),
        (1320, true),
        (1439, true),
        (0, true),
        (479, true),
        (480, false),
        (720, false)
    ])
    func spanningWindowBoundaries(minute: Int, expected: Bool) {
        #expect(QuietHours.standard.contains(minuteOfDay: minute) == expected)
    }

    @Test(arguments: [
        (779, false),
        (780, true),
        (899, true),
        (900, false)
    ])
    func sameDayWindowBoundaries(minute: Int, expected: Bool) {
        let window = QuietHours(startHour: 13, endHour: 15)
        #expect(!window.spansMidnight)
        #expect(window.contains(minuteOfDay: minute) == expected)
    }

    @Test func emptyWindowContainsNothing() {
        #expect(QuietHours.none.isEmpty)
        #expect(!QuietHours.none.contains(minuteOfDay: 0))
        #expect(!QuietHours.none.contains(date(1, 3), calendar: utc))
    }

    @Test func outOfRangeMinutesWrapAroundTheClock() {
        let window = QuietHours(startMinute: -60, endMinute: 1500)
        #expect(window.startMinute == 23 * 60)
        #expect(window.endMinute == 60)
    }

    @Test func windowStartIsTheEveningBeforeAnEarlyMorningMoment() {
        let start = QuietHours.standard.windowStart(containing: date(2, 3), calendar: utc)
        #expect(start == date(1, 22))
    }

    @Test func windowStartIsTodayForALateEveningMoment() {
        let start = QuietHours.standard.windowStart(containing: date(2, 23, 15), calendar: utc)
        #expect(start == date(2, 22))
    }

    @Test func aMomentExactlyAtTheStartIsInsideItsOwnWindow() {
        let start = QuietHours.standard.windowStart(containing: date(2, 22), calendar: utc)
        #expect(start == date(2, 22))
    }

    @Test func windowStartIsNilOutsideTheWindow() {
        #expect(QuietHours.standard.windowStart(containing: date(2, 8), calendar: utc) == nil)
        #expect(QuietHours.standard.windowStart(containing: date(2, 15), calendar: utc) == nil)
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(QuietHours(startHour: 23, endHour: 6))
        let decoded = try JSONDecoder().decode(QuietHours.self, from: data)
        #expect(decoded == QuietHours(startHour: 23, endHour: 6))
    }
}
