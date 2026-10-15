import BLTDesign
import Testing

struct AccessibilityIDTests {
    @Test func twoWayCourseIDsAreDistinctAndNamespaced() {
        let ids = [
            AccessibilityID.languageContinue,
            AccessibilityID.homeLanguage,
            AccessibilityID.homeContinueLesson,
            AccessibilityID.homeOtherLessons,
            AccessibilityID.settingsLanguage,
            AccessibilityID.settingsLanguageConfirm,
            AccessibilityID.settingsLanguageCancel,
            AccessibilityID.languageOption("zz"),
            AccessibilityID.homeLevel(1),
            AccessibilityID.settingsLanguageOption("zz")
        ]
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.contains(".") })
    }

    @Test func parameterisedIDsIncludeTheirArgument() {
        #expect(AccessibilityID.languageOption("zz") == "language.option.zz")
        #expect(AccessibilityID.homeLevel(3) == "home.level.3")
        #expect(AccessibilityID.settingsLanguageOption("zz") == "settings.language.option.zz")
        #expect(AccessibilityID.homeLevel(1) != AccessibilityID.homeLevel(2))
    }

    private let dailyPracticeIDs: [String] = [
        AccessibilityID.homeStreakChip, AccessibilityID.homeTodayCard, AccessibilityID.homeWeekStrip,
        AccessibilityID.homeChapter(1), AccessibilityID.homeChapter(2),
        AccessibilityID.sessionStreak, AccessibilityID.sessionGoalMet, AccessibilityID.sessionWeekStrip,
        AccessibilityID.sessionNextFreeze, AccessibilityID.sessionMilestone,
        AccessibilityID.streakScreen, AccessibilityID.streakCount, AccessibilityID.streakDeadline,
        AccessibilityID.streakLongest, AccessibilityID.streakFreezes, AccessibilityID.streakGoalDays,
        AccessibilityID.streakCalendar, AccessibilityID.streakDone,
        AccessibilityID.streakCalendarDay(1), AccessibilityID.streakCalendarDay(31),
        AccessibilityID.weekStripDay(0), AccessibilityID.weekStripDay(6),
        AccessibilityID.settingsDailyPractice, AccessibilityID.settingsReminders,
        AccessibilityID.settingsQuietHoursStart, AccessibilityID.settingsQuietHoursEnd,
        AccessibilityID.settingsDailyGoal, AccessibilityID.settingsNotificationsDenied,
        AccessibilityID.settingsNotificationsOpenSettings,
        AccessibilityID.notificationsPrompt, AccessibilityID.notificationsPromptAllow,
        AccessibilityID.notificationsPromptNotNow
    ]

    @Test func dailyPracticeIDsAreDistinctAndNamespaced() {
        #expect(Set(dailyPracticeIDs).count == dailyPracticeIDs.count)
        #expect(dailyPracticeIDs.allSatisfy { $0.contains(".") && !$0.contains(" ") })
    }

    @Test func dailyPracticeIDsDoNotCollideWithExistingOnes() {
        let existing: [String] = [
            AccessibilityID.feedbackCorrect, AccessibilityID.continueButton, AccessibilityID.settingsReset,
            AccessibilityID.greeting, AccessibilityID.homeLanguage, AccessibilityID.homeContinueLesson,
            AccessibilityID.homeOtherLessons, AccessibilityID.settingsLanguage, AccessibilityID.homeExam,
            AccessibilityID.homeLevel(1), AccessibilityID.examResult, AccessibilityID.endSessionButton
        ]
        #expect(Set(existing).isDisjoint(with: dailyPracticeIDs))
    }

    @Test func parameterisedDailyPracticeIDsIncludeTheirArgument() {
        #expect(AccessibilityID.homeChapter(2) == "home.chapter.2")
        #expect(AccessibilityID.streakCalendarDay(14) == "streak.calendar.day.14")
        #expect(AccessibilityID.weekStripDay(3) == "weekStrip.day.3")
        #expect(AccessibilityID.homeChapter(1) != AccessibilityID.homeChapter(2))
    }
}
