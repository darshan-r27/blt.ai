import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

struct StreakDeadlineTextTests {
    private let locale = Locale(identifier: "en_US")

    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int, zone: String = "UTC") -> Date {
        let components = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar(zone).date(from: components) ?? .distantPast
    }

    /// Recent system versions write "7:40 PM" with a narrow no-break space; compare with a plain one.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func text(_ deadline: StreakDeadline?, now: Date, zone: String = "UTC", locale: Locale? = nil) -> String {
        plain(StreakDeadlineText.text(
            for: deadline, now: now, calendar: calendar(zone), locale: locale ?? self.locale
        ))
    }

    @Test func aDeadlineLaterTodayIsToday() {
        let deadline = StreakDeadline(practiseBy: date(14, 19, 40), freezeWouldCover: false)
        #expect(text(deadline, now: date(14, 9, 0)) == "Practise by 7:40 PM today.")
    }

    @Test func aDeadlineOnTheNextDateIsTomorrow() {
        let deadline = StreakDeadline(practiseBy: date(15, 19, 40), freezeWouldCover: false)
        #expect(text(deadline, now: date(14, 20, 0)) == "Practise by 7:40 PM tomorrow.")
    }

    @Test func aDeadlineJustAfterMidnightIsTomorrowEvenIfItIsLessThanADayAway() {
        let deadline = StreakDeadline(practiseBy: date(15, 0, 30), freezeWouldCover: false)
        #expect(text(deadline, now: date(14, 23, 0)) == "Practise by 12:30 AM tomorrow.")
    }

    @Test func aFreezeThatWouldCoverAMissIsMentioned() {
        let deadline = StreakDeadline(practiseBy: date(15, 19, 40), freezeWouldCover: true)
        #expect(
            text(deadline, now: date(14, 20, 0))
                == "Practise by 7:40 PM tomorrow. If you miss it, a freeze will keep your streak going."
        )
    }

    @Test func noFreezeMeansNothingIsSaidAboutOne() {
        let deadline = StreakDeadline(practiseBy: date(14, 19, 40), freezeWouldCover: false)
        #expect(!text(deadline, now: date(14, 9, 0)).contains("freeze"))
    }

    @Test func noStreakInvitesTheLearnerToStartOne() {
        #expect(text(nil, now: date(14, 9, 0)) == "Finish a chapter to start a new streak.")
    }

    @Test func todayAndTomorrowFollowTheCalendarsTimeZone() {
        // 02:40 UTC on the 15th is 7:40 PM on the 14th in Los Angeles (daylight time, UTC-7).
        let deadline = StreakDeadline(practiseBy: date(15, 2, 40), freezeWouldCover: false)
        let now = date(14, 12, 0, zone: "America/Los_Angeles")
        #expect(text(deadline, now: now, zone: "America/Los_Angeles") == "Practise by 7:40 PM today.")
        #expect(text(deadline, now: date(14, 12, 0)) == "Practise by 2:40 AM tomorrow.")
    }

    @Test func theTimeFollowsTheLocale() {
        let deadline = StreakDeadline(practiseBy: date(15, 19, 40), freezeWouldCover: false)
        let british = text(deadline, now: date(14, 20, 0), locale: Locale(identifier: "en_GB"))
        #expect(british == "Practise by 19:40 tomorrow.")
    }

    @Test func aDeadlineBeyondTomorrowNamesTheWeekday() {
        let deadline = StreakDeadline(practiseBy: date(17, 19, 40), freezeWouldCover: false)
        #expect(text(deadline, now: date(14, 9, 0)) == "Practise by 7:40 PM on Saturday.")
    }
}
