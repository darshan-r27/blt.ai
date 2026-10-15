public enum AccessibilityID {
    public static let feedbackCorrect = "feedback.correct"
    public static let feedbackWrongRegister = "feedback.wrongRegister"
    public static let feedbackNotQuite = "feedback.notQuite"
    public static let badgeUnreviewed = "badge.unreviewed"
    public static let continueButton = "continue.button"
    public static let progressRegisterAccuracy = "progress.registerAccuracy"
    public static let progressLearned = "progress.learned"
    public static let progressDue = "progress.due"
    public static let settingsReset = "settings.reset"
    public static let endSessionButton = "session.end.button"
    public static let endSessionConfirm = "session.end.confirm"
    public static let endSessionKeepGoing = "session.end.keepGoing"
    public static let introStart = "intro.start"
    public static let nameField = "name.field"
    public static let nameContinue = "name.continue"
    public static let nameError = "name.error"
    public static let greeting = "home.greeting"
    public static let settingsChangeName = "settings.changeName"
    public static let changeNameField = "changeName.field"
    public static let changeNameSave = "changeName.save"
    public static let changeNameCancel = "changeName.cancel"
    public static let settingsImportLessons = "settings.importLessons"
    public static let settingsRemoveImported = "settings.removeImported"
    public static let settingsImportStatus = "settings.importStatus"

    // Two-way course (DECISIONS 042, 043). Added up front so the onboarding, Home and Settings chunks
    // do not collide on this file. A language is passed as its raw value (`CourseLanguage.rawValue`).
    public static let languageContinue = "language.continue"
    public static let homeLanguage = "home.language"
    public static let homeContinueLesson = "home.continueLesson"
    public static let homeOtherLessons = "home.otherLessons"
    public static let settingsLanguage = "settings.language"
    public static let settingsLanguageConfirm = "settings.language.confirm"
    public static let settingsLanguageCancel = "settings.language.cancel"

    public static func scenarioCard(_ scenarioID: String) -> String {
        "scenario.card.\(scenarioID)"
    }

    public static func languageOption(_ language: String) -> String {
        "language.option.\(language)"
    }

    public static func homeLevel(_ number: Int) -> String {
        "home.level.\(number)"
    }

    public static func settingsLanguageOption(_ language: String) -> String {
        "settings.language.option.\(language)"
    }
    public static let homeExam = "home.exam"
    public static let examStart = "exam.start"
    public static let examEndButton = "exam.end.button"
    public static let examEndConfirm = "exam.end.confirm"
    public static let examKeepGoing = "exam.end.keepGoing"
    public static let examResult = "exam.result"
    public static let examDone = "exam.done"

    // Daily practice (plan.md, "Daily practice"). Added up front so Home (S4), the session end and streak
    // screen (S5) and Settings (S6) do not collide on this file.

    // Home
    public static let homeStreakChip = "home.streak.chip"
    public static let homeTodayCard = "home.today.card"
    public static let homeWeekStrip = "home.weekStrip"

    /// Chapter row 1 or 2 inside the Today card.
    public static func homeChapter(_ number: Int) -> String {
        "home.chapter.\(number)"
    }

    // Session end
    public static let sessionStreak = "session.streak"
    public static let sessionGoalMet = "session.goalMet"
    public static let sessionWeekStrip = "session.weekStrip"
    public static let sessionNextFreeze = "session.nextFreeze"
    public static let sessionMilestone = "session.milestone"

    // Streak screen
    public static let streakScreen = "streak.screen"
    public static let streakCount = "streak.count"
    public static let streakDeadline = "streak.deadline"
    public static let streakLongest = "streak.longest"
    public static let streakFreezes = "streak.freezes"
    public static let streakGoalDays = "streak.goalDays"
    public static let streakCalendar = "streak.calendar"
    public static let streakDone = "streak.done"
    public static let streakPreviousMonth = "streak.calendar.previous"
    public static let streakNextMonth = "streak.calendar.next"

    /// One day cell of the month calendar, by day of the month (1...31).
    public static func streakCalendarDay(_ dayOfMonth: Int) -> String {
        "streak.calendar.day.\(dayOfMonth)"
    }

    /// One day of the week strip, by position from the first weekday (0...6).
    public static func weekStripDay(_ index: Int) -> String {
        "weekStrip.day.\(index)"
    }

    // Settings: Daily practice section
    public static let settingsDailyPractice = "settings.dailyPractice"
    public static let settingsReminders = "settings.reminders"
    public static let settingsQuietHoursStart = "settings.quietHours.start"
    public static let settingsQuietHoursEnd = "settings.quietHours.end"
    public static let settingsDailyGoal = "settings.dailyGoal"
    /// The one-line explanation shown under the reminders toggle when notifications are off in iOS Settings.
    public static let settingsNotificationsDenied = "settings.notifications.denied"
    /// The "Turn on in iOS Settings" button beside that explanation.
    public static let settingsNotificationsOpenSettings = "settings.notifications.openSettings"

    // Notification permission pre-prompt (shown before the system dialog)
    public static let notificationsPrompt = "notifications.prompt"
    public static let notificationsPromptAllow = "notifications.prompt.allow"
    public static let notificationsPromptNotNow = "notifications.prompt.notNow"
}
