import XCTest

/// Launch arguments that seed daily practice (UITestLaunch.swift lists them). A seeded launch also fixes the app's
/// clock to noon today, so these never depend on the hour the test runs at.
enum PracticeArguments {
    /// A streak of `days` days ending yesterday evening, in both courses or in one.
    static func streak(_ days: Int, in language: UITestLanguage? = nil) -> String {
        language.map { "--uitest-practice-\($0.rawValue)=\(days)" } ?? "--uitest-practice=\(days)"
    }

    /// What the fake reminder scheduler reports. Without this a launch is `authorized`, so no test meets the
    /// permission pre-prompt by accident.
    enum Notifications: String {
        case authorized
        case notDetermined
        case denied
    }

    static func notifications(_ status: Notifications) -> String {
        "--uitest-notifications=\(status.rawValue)"
    }
}

/// Accessibility identifiers of the daily-practice screens, copied as literals like the rest of `AXID` (source of
/// truth: Packages/BLTKit/Sources/BLTDesign/AccessibilityID.swift).
extension AXID {
    static let homeStreakChip = "home.streak.chip"
    static let homeTodayCard = "home.today.card"
    static let sessionStreak = "session.streak"
    static let sessionGoalMet = "session.goalMet"
    static let streakScreen = "streak.screen"
    static let streakCount = "streak.count"
    static let streakDeadline = "streak.deadline"
    static let streakLongest = "streak.longest"
    static let streakDone = "streak.done"
    static let settingsDailyPractice = "settings.dailyPractice"
    static let settingsReminders = "settings.reminders"
    static let settingsQuietHoursStart = "settings.quietHours.start"
    static let settingsQuietHoursEnd = "settings.quietHours.end"
    static let settingsDailyGoal = "settings.dailyGoal"
    static let settingsNotificationsDenied = "settings.notifications.denied"
    static let settingsNotificationsOpenSettings = "settings.notifications.openSettings"
    static let notificationsPrompt = "notifications.prompt"
    static let notificationsPromptAllow = "notifications.prompt.allow"
    static let notificationsPromptNotNow = "notifications.prompt.notNow"
}

extension BLTUITestCase {
    /// Answers every question of the fixture session correctly, so the summary shows. A second session on the
    /// same fixture has nothing due, so it passes `reviewAnyway` to take the "Review anyway" step first.
    func finishFixtureSession(
        _ app: XCUIApplication,
        language: UITestLanguage = .tamil,
        reviewAnyway: Bool = false
    ) throws {
        openFixtureScenario(app, language: language)
        if reviewAnyway {
            tap(app.buttons["Review anyway"], "Review anyway")
        }
        for _ in FixtureQuestion.all(language) {
            let question = try currentQuestion(app, language: language)
            choose(question.canonical, in: app)
            requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
            tapContinue(app)
        }
        requireExists(app.staticTexts["Session finished"], "the finished summary")
    }

    /// The Settings button on Home, then the Settings screen.
    func goToSettings(_ app: XCUIApplication) {
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")
    }

    /// Settings, then Language I'm learning, the other language and Switch: ends on that language's Home.
    func switchLanguage(to language: UITestLanguage, in app: XCUIApplication) {
        goToSettings(app)
        tap(app.buttons[AXID.settingsLanguage], "the Language I'm learning row")
        tap(app.buttons[AXID.settingsLanguageOption(language)], "the \(language.displayName) option")
        requireExists(app.staticTexts["Switch to \(language.displayName)?"], "the Switch confirmation")
        // The confirmation is an action sheet; its button shares nothing with the screen behind it.
        tap(app.sheets.buttons["Switch"].firstMatch, "Switch in the confirmation")
        requireExists(app.element(AXID.greeting), "Home after switching")
        requireLabel(of: app.element(AXID.homeLanguage), containing: language.displayName)
    }

    /// Swipes up (at most a few times) until the element can be tapped.
    func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        requireExists(element, "the element to scroll to")
        var swipes = 0
        while !element.isHittable && swipes < 6 {
            if app.keyboards.firstMatch.exists {
                // `swipeUp()` starts near the bottom of the screen, which is the keyboard while a name field has
                // focus, so nothing would scroll. Drag inside the scroll view, from above the keyboard.
                let scroller = app.scrollViews.firstMatch
                let from = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                let to = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                from.press(forDuration: 0.1, thenDragTo: to)
            } else {
                app.swipeUp()
            }
            swipes += 1
        }
    }
}
