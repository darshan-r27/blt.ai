import XCTest

/// Daily practice, full tier (DECISIONS 045, 047): the Settings section, Reset progress and the streak, a streak per
/// language, and the notification pre-prompt. The rules behind them (what a streak is, what the prompt decides,
/// what gets rescheduled) are checked in the package; these tests stay because the screens and the whole-app
/// wiring are what is under test. The PR-tier happy paths for the streak are in `HappyPathUITests`.
///
/// Nothing here touches real notifications: UI-test launches use a fake reminder scheduler whose permission
/// state a launch argument sets, and a fake "open iOS Settings".
@MainActor
final class DailyPracticeUITests: BLTUITestCase {
    // MARK: Helpers

    /// Home, then Settings, scrolled to the Daily practice section.
    private func openDailyPractice(_ arguments: [String] = []) -> XCUIApplication {
        let app = launchHome(extraArguments: arguments)
        goToSettings(app)
        scrollIntoView(app.element(AXID.settingsReminders), in: app)
        return app
    }

    /// The picker's current value is part of its label ("Quiet hours start, 10 PM").
    private func requireHour(_ element: XCUIElement, containing digits: String, _ meridiem: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", digits, meridiem)
        let matches = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [matches], timeout: Self.timeout), .completed, "Got '\(element.label)'")
    }

    /// Taps the switch itself, at the right end of its row; a tap in the middle of the row lands on the label.
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    // MARK: Settings: Daily practice

    func testSectionShowsRemindersOnQuietHoursAndTheGoal() {
        let app = openDailyPractice()

        let toggle = app.switches[AXID.settingsReminders]
        requireExists(toggle, "the Reminders toggle")
        XCTAssertTrue(isOn(toggle), "Reminders start on when notifications are allowed")
        requireHour(app.element(AXID.settingsQuietHoursStart), containing: "10", "PM")
        requireHour(app.element(AXID.settingsQuietHoursEnd), containing: "8", "AM")
        requireLabel(of: app.element(AXID.settingsDailyGoal), containing: "2 chapters a day")
        XCTAssertFalse(app.element(AXID.settingsNotificationsDenied).exists)
    }

    func testRemindersCanBeSwitchedOffAndOn() {
        let app = openDailyPractice()
        let toggle = app.switches[AXID.settingsReminders]
        requireExists(toggle, "the Reminders toggle")

        flip(toggle)
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: Self.timeout), .completed, "Reminders did not switch off")

        flip(toggle)
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: Self.timeout), .completed, "Reminders did not switch on")
    }

    func testQuietHoursCanBeChanged() {
        let app = openDailyPractice()
        let start = app.element(AXID.settingsQuietHoursStart)
        requireExists(start, "the quiet hours start picker")

        start.tap()
        // The menu lists the 24 hours; "9 PM" is the one that starts with a 9 and says PM.
        let nine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '9' AND label CONTAINS 'PM'")).firstMatch
        tap(nine, "9 PM in the menu")

        requireHour(app.element(AXID.settingsQuietHoursStart), containing: "9", "PM")
        requireHour(app.element(AXID.settingsQuietHoursEnd), containing: "8", "AM")
    }

    func testDeniedNotificationsAreExplainedAndTheOpenSettingsButtonOnlyCallsTheFake() {
        let app = openDailyPractice([PracticeArguments.notifications(.denied)])

        requireExists(app.element(AXID.settingsNotificationsDenied), "the explanation for denied notifications")
        let toggle = app.switches[AXID.settingsReminders]
        requireExists(toggle, "the Reminders toggle")
        XCTAssertFalse(toggle.isEnabled, "The toggle cannot work while iOS blocks notifications")
        XCTAssertFalse(isOn(toggle))

        let open = app.buttons[AXID.settingsNotificationsOpenSettings]
        tap(open, "Open iOS Settings")
        // The fake does nothing, so this app stays in front and the real Settings app is not launched.
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertNotEqual(XCUIApplication(bundleIdentifier: "com.apple.Preferences").state, .runningForeground)
        requireExists(app.element(AXID.settingsNotificationsDenied), "the explanation, still on screen")
    }

    // MARK: Reset progress and one streak per language

    func testResetClearsTheStreakOfTheCurrentLanguageOnly() {
        let app = launchHome(
            language: .tamil,
            extraArguments: [PracticeArguments.streak(3, in: .tamil), PracticeArguments.streak(5, in: .telugu)]
        )
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "3 day streak")

        goToSettings(app)
        tap(app.element(AXID.settingsReset), "Reset progress")
        requireExists(app.staticTexts["Reset Tamil progress?"], "the confirmation naming Tamil")
        let confirm = app.sheets.buttons["Reset progress"].firstMatch
        tap(confirm, "Reset progress in the confirmation")
        requireExists(app.staticTexts["Progress was reset."], "the reset confirmation message")
        app.navigationBars.buttons.firstMatch.tap()

        requireLabel(of: app.element(AXID.homeStreakChip), containing: "No streak yet")
        switchLanguage(to: .telugu, in: app)
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "5 day streak")
    }

    func testEachLanguageKeepsItsOwnStreak() {
        let app = launchHome(
            language: .tamil,
            extraArguments: [PracticeArguments.streak(3, in: .tamil), PracticeArguments.streak(5, in: .telugu)]
        )
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "3 day streak")

        switchLanguage(to: .telugu, in: app)
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "5 day streak")

        switchLanguage(to: .tamil, in: app)
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "3 day streak")
    }

    func testFinishingASessionInOneLanguageLeavesTheOtherStreakAlone() throws {
        let app = launchHome(
            language: .tamil,
            extraArguments: [PracticeArguments.streak(3, in: .tamil), PracticeArguments.streak(5, in: .telugu)]
        )

        try finishFixtureSession(app)
        tap(app.buttons["Done"], "Done")
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "4 day streak")

        switchLanguage(to: .telugu, in: app)
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "5 day streak")
    }

    // MARK: The notification pre-prompt

    func testPrePromptAppearsAfterTheFirstFinishedSessionAndNotNowDoesNotAskAgain() throws {
        let app = launchHome(extraArguments: [PracticeArguments.notifications(.notDetermined)])

        try finishFixtureSession(app)
        tap(app.buttons["Done"], "Done")

        requireExists(app.element(AXID.notificationsPrompt), "the notification pre-prompt")
        tap(app.buttons[AXID.notificationsPromptNotNow], "Not now")
        requireGone(app.element(AXID.notificationsPrompt), "the pre-prompt")
        requireExists(app.element(AXID.greeting), "Home after Not now")

        // A second session finishes the day's goal; the prompt must not come back.
        try finishFixtureSession(app, reviewAnyway: true)
        tap(app.buttons["Done"], "Done")
        requireLabel(of: app.element(AXID.homeTodayCard), containing: "2 of 2")
        requireGone(app.element(AXID.notificationsPrompt), "the pre-prompt, which is never repeated", timeout: 3)
    }

    func testAllowingInThePrePromptTurnsRemindersOn() throws {
        let app = launchHome(extraArguments: [PracticeArguments.notifications(.notDetermined)])

        try finishFixtureSession(app)
        tap(app.buttons["Done"], "Done")
        tap(app.buttons[AXID.notificationsPromptAllow], "Allow reminders")
        requireGone(app.element(AXID.notificationsPrompt), "the pre-prompt")

        goToSettings(app)
        scrollIntoView(app.element(AXID.settingsReminders), in: app)
        let on = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '1'"),
            object: app.switches[AXID.settingsReminders]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: Self.timeout), .completed, "Reminders are not on")
    }

    func testNoPrePromptWhenNotificationsAreAlreadyAllowed() throws {
        let app = launchHome()

        try finishFixtureSession(app)
        tap(app.buttons["Done"], "Done")

        requireExists(app.element(AXID.homeTodayCard), "Home")
        requireLabel(of: app.element(AXID.homeTodayCard), containing: "1 of 2")
        requireGone(app.element(AXID.notificationsPrompt), "the pre-prompt", timeout: 3)
    }
}
