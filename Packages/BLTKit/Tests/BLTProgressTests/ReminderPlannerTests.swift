import BLTCore
import BLTProgress
import Foundation
import Testing

struct ReminderPlannerTests {
    private let planner = ReminderPlanner()

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private var utc: Calendar {
        calendar("UTC")
    }

    private func date(
        _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar
    ) -> Date {
        var parts = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        return parts.date ?? .distantPast
    }

    /// June 2026 in UTC, so day arithmetic is easy to read.
    private func june(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        date(6, day, hour, minute, in: utc)
    }

    private func plan(
        finish: Date,
        now: Date? = nil,
        calendar: Calendar? = nil,
        quietHours: QuietHours = .standard,
        language: CourseLanguage = .tamil,
        streak: Int = 5
    ) -> ReminderPlan {
        planner.plan(
            lastSessionFinish: finish,
            now: now ?? finish,
            calendar: calendar ?? utc,
            quietHours: quietHours,
            context: ReminderContext(language: language, streakLength: streak)
        )
    }

    // MARK: Quiet hours

    @Test func neitherReminderInQuietHoursFiresTwentyAndTwentyThreeHoursLater() {
        let result = plan(finish: june(1, 14))
        #expect(result.reminders.map(\.slot) == [.first, .second])
        #expect(result.reminders.map(\.fireDate) == [june(2, 10), june(2, 13)])
    }

    @Test func bothInQuietHoursMoveToTheSameMomentSoOneIsSent() {
        // 05:00 plus 20 and 23 hours is 01:00 and 04:00, both in the window that began at 22:00.
        let result = plan(finish: june(1, 5))
        #expect(result.reminders.count == 1)
        #expect(result.reminders.first?.slot == .first)
        #expect(result.reminders.first?.fireDate == june(1, 21, 30))
    }

    @Test func onlyTheFirstInQuietHoursMovesToTheEveningBefore() {
        // 10:00 plus 20 hours is 06:00 (quiet); plus 23 hours is 09:00 (fine).
        let result = plan(finish: june(1, 10))
        #expect(result.reminders.map(\.slot) == [.first, .second])
        #expect(result.reminders.map(\.fireDate) == [june(1, 21, 30), june(2, 9)])
    }

    @Test func onlyTheSecondInQuietHoursMovesToTheEveningBefore() {
        // 01:00 plus 20 hours is 21:00 (fine); plus 23 hours is 00:00 (quiet), which moves to 21:30.
        let result = plan(finish: june(1, 1))
        #expect(result.reminders.map(\.slot) == [.first, .second])
        #expect(result.reminders.map(\.fireDate) == [june(1, 21), june(1, 21, 30)])
    }

    @Test func aReminderExactlyWhenQuietHoursEndIsAllowed() {
        // 12:00 plus 20 hours is exactly 08:00.
        let result = plan(finish: june(1, 12))
        #expect(result.reminders.map(\.fireDate) == [june(2, 8), june(2, 11)])
    }

    @Test func aReminderExactlyWhenQuietHoursStartMovesBack() {
        // 02:00 plus 20 hours is exactly 22:00, which is inside; plus 23 hours is 01:00. Both go to 21:30.
        let result = plan(finish: june(1, 2))
        #expect(result.reminders.map(\.slot) == [.first])
        #expect(result.reminders.first?.fireDate == june(1, 21, 30))
    }

    @Test func aReminderOneMinuteBeforeQuietHoursStartIsLeftAlone() {
        // 01:59 plus 20 hours is 21:59.
        let result = plan(finish: june(1, 1, 59))
        #expect(result.reminders.first?.fireDate == june(1, 21, 59))
    }

    @Test func aWindowThatDoesNotSpanMidnightMovesAReminderBackOnTheSameDay() {
        let afternoon = QuietHours(startHour: 13, endHour: 15)
        // 17:00 plus 20 hours is 13:00 (start of the window), plus 23 hours is 16:00.
        let result = plan(finish: june(1, 17), quietHours: afternoon)
        #expect(result.reminders.map(\.fireDate) == [june(2, 12, 30), june(2, 16)])
    }

    @Test func aCustomWindowSpanningMidnightIsRespected() {
        let late = QuietHours(startMinute: 23 * 60 + 30, endMinute: 6 * 60 + 30)
        // 03:00 plus 20 hours is 23:00 (fine); plus 23 hours is 02:00 (quiet), which moves to 23:00.
        let result = plan(finish: june(1, 3), quietHours: late)
        #expect(result.reminders.map(\.fireDate) == [june(1, 23)])
    }

    @Test func noQuietHoursMeansNothingMoves() {
        let result = plan(finish: june(1, 5), quietHours: .none)
        #expect(result.reminders.map(\.fireDate) == [june(2, 1), june(2, 4)])
    }

    @Test func aWindowAlmostAWholeDayLongDropsAReminderInsteadOfLooping() {
        let nearlyAllDay = QuietHours(startMinute: 10, endMinute: 0)
        let result = plan(finish: june(1, 12), quietHours: nearlyAllDay)
        #expect(result.isEmpty)
    }

    // MARK: Past times

    @Test func aReminderAlreadyInThePastIsDropped() {
        // First is due 08:00 on the 2nd; it is 08:30 now, so only the second remains.
        let result = plan(finish: june(1, 12), now: june(2, 8, 30))
        #expect(result.reminders.map(\.slot) == [.second])
    }

    @Test func aReminderDueExactlyNowIsDropped() {
        let result = plan(finish: june(1, 12), now: june(2, 8))
        #expect(result.reminders.map(\.slot) == [.second])
    }

    @Test func everyReminderInThePastGivesAnEmptyPlan() {
        let result = plan(finish: june(1, 12), now: june(3, 12))
        #expect(result.isEmpty)
    }

    @Test func aMovedReminderThatIsAlreadyPastIsDropped() {
        // Both would move to 21:30 on the 1st, but it is 22:00 already.
        let result = plan(finish: june(1, 5), now: june(1, 22))
        #expect(result.isEmpty)
    }

    // MARK: Daylight saving time

    @Test func springForwardKeepsTheTwentyAndTwentyThreeHourGapInRealTime() {
        let newYork = calendar("America/New_York")
        // Mar 7 12:00 EST. Twenty real hours later the clock reads 09:00 EDT, not 08:00.
        let finish = date(3, 7, 12, in: newYork)
        let result = plan(finish: finish, calendar: newYork)
        let expected = [finish.addingTimeInterval(20 * 3600), finish.addingTimeInterval(23 * 3600)]
        #expect(result.reminders.map(\.fireDate) == expected)
        let hours = result.reminders.map { newYork.component(.hour, from: $0.fireDate) }
        #expect(hours == [9, 12])
    }

    @Test func springForwardNightMovesBothRemindersToTheEveningBefore() {
        let newYork = calendar("America/New_York")
        // Mar 7 05:00 EST; the reminders are due at 01:00 EST and 05:00 EDT on Mar 8, both quiet.
        let result = plan(finish: date(3, 7, 5, in: newYork), calendar: newYork)
        #expect(result.reminders.count == 1)
        #expect(result.reminders.first?.fireDate == date(3, 7, 21, 30, in: newYork))
    }

    @Test func fallBackNightMovesBothRemindersToTheEveningBefore() {
        let newYork = calendar("America/New_York")
        // Oct 31 09:00 EDT; the reminders are due at 04:00 EST and 07:00 EST on Nov 1, both quiet.
        let result = plan(finish: date(10, 31, 9, in: newYork), calendar: newYork)
        #expect(result.reminders.count == 1)
        #expect(result.reminders.first?.fireDate == date(10, 31, 21, 30, in: newYork))
    }

    @Test func aWindowStartingInTheSpringForwardGapStillGivesAnAllowedEarlierTime() {
        let newYork = calendar("America/New_York")
        let gapWindow = QuietHours(startMinute: 2 * 60 + 30, endMinute: 6 * 60)
        // Mar 7 08:00 EST; the first reminder is due at 05:00 EDT on Mar 8, inside the window whose
        // 02:30 start does not exist that day.
        let finish = date(3, 7, 8, in: newYork)
        let result = plan(finish: finish, calendar: newYork, quietHours: gapWindow)
        let due = finish.addingTimeInterval(20 * 3600)
        let first = result.reminders.first
        #expect(first != nil)
        #expect((first?.fireDate ?? .distantFuture) < due)
        #expect(!gapWindow.contains(first?.fireDate ?? due, calendar: newYork))
    }

    // MARK: Time zone

    @Test func theSameInstantIsQuietOrNotDependingOnTheTimeZone() {
        // Due 20:00 UTC on the 1st: fine in UTC, but 05:00 in Tokyo, which moves to 21:30 JST the evening
        // before (12:30 UTC). The second is due 23:00 UTC (quiet in UTC) and 08:00 in Tokyo (allowed).
        let finish = june(1, 0)
        let inUTC = plan(finish: finish, now: finish.addingTimeInterval(-1), calendar: utc)
        let inTokyo = plan(finish: finish, now: finish.addingTimeInterval(-1), calendar: calendar("Asia/Tokyo"))
        #expect(inUTC.reminders.map(\.fireDate) == [june(1, 20), june(1, 21, 30)])
        #expect(inTokyo.reminders.map(\.fireDate) == [june(1, 12, 30), june(1, 23)])
    }

    // MARK: Text

    @Test func textNamesTheStreakAndTheLanguage() {
        let result = plan(finish: june(1, 14), language: .telugu, streak: 12)
        for reminder in result.reminders {
            #expect(reminder.title.contains("12"))
            #expect(reminder.body.contains("Telugu"))
        }
    }

    @Test func textForAStreakOfZeroNamesOnlyTheLanguage() {
        let result = plan(finish: june(1, 14), language: .tamil, streak: 0)
        for reminder in result.reminders {
            #expect(reminder.title.contains("Tamil"))
            #expect(reminder.body.contains("Tamil"))
            #expect(!(reminder.title + reminder.body).contains { $0.isNumber })
        }
    }

    @Test func textChangesOnlyByLanguageAndStreakNumber() {
        for slot in ReminderSlot.allCases {
            let tamil = ReminderPlanner.text(for: slot, language: .tamil, streakLength: 7)
            let telugu = ReminderPlanner.text(for: slot, language: .telugu, streakLength: 7)
            #expect(tamil.title == telugu.title)
            #expect(tamil.body.replacing("Tamil", with: "Telugu") == telugu.body)
            let other = ReminderPlanner.text(for: slot, language: .tamil, streakLength: 40)
            #expect(tamil.title.replacing("7", with: "40") == other.title)
            #expect(tamil.body == other.body)
        }
    }

    @Test func textIsPlainAsciiCalmEnglishWithNoPhraseOrName() {
        let alarming = ["!", "urgent", "lose", "lost", "hurry", "expire", "last chance", "don't", "warning"]
        for slot in ReminderSlot.allCases {
            for streak in [0, 1, 99] {
                for language in CourseLanguage.allCases {
                    let text = ReminderPlanner.text(for: slot, language: language, streakLength: streak)
                    let combined = (text.title + " " + text.body).lowercased()
                    #expect(combined.unicodeScalars.allSatisfy { $0.isASCII })
                    for word in alarming {
                        #expect(!combined.contains(word))
                    }
                }
            }
        }
    }

    @Test func aNegativeStreakIsTreatedAsNoStreak() {
        let text = ReminderPlanner.text(for: .first, language: .tamil, streakLength: -3)
        #expect(!text.title.contains("-"))
        #expect(text.title.contains("Tamil"))
    }

    @Test func eachSlotHasItsOwnFixedIdentifier() {
        let identifiers = ReminderSlot.allCases.map(\.identifier)
        #expect(Set(identifiers).count == 2)
        #expect(identifiers == ["ai.blt.reminder.first", "ai.blt.reminder.second"])
        #expect(ReminderSlot(identifier: "ai.blt.reminder.second") == .second)
        #expect(ReminderSlot(identifier: "other") == nil)
    }
}
