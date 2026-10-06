import XCTest

/// Answers survive a terminate and relaunch; the reset launch argument and Settings' Reset progress clear them.
@MainActor
final class PersistenceUITests: BLTUITestCase {
    /// Answers one item correctly and ends the session, leaving the app on Home.
    private func answerOneItemAndEndSession(_ app: XCUIApplication) throws {
        openFixtureScenario(app)
        let question = try currentQuestion(app)
        choose(question.canonical, in: app)
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        confirmEndSession(app)
        requireLabel(of: app.element(AXID.fixtureScenarioCard), containing: "1 of 2 answered")
    }

    private func openProgress(_ app: XCUIApplication) {
        tap(app.buttons["Progress"], "the Progress button")
        requireExists(app.navigationBars["Progress"], "the Progress screen")
    }

    private func openSettings(_ app: XCUIApplication) {
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Reset progress in Settings")
    }

    /// The "Attempts so far" row is one combined element whose label holds its title and value.
    private func attemptsRow(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Attempts so far'")).firstMatch
    }

    func testAnsweredFigureAndAttemptsSurviveRelaunch() throws {
        let app = launchHome()
        try answerOneItemAndEndSession(app)

        relaunch(app)

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting after relaunch")
        XCTAssertEqual(greeting.label, "Hi ZzTest", "The saved name must survive too")
        requireLabel(of: app.element(AXID.fixtureScenarioCard), containing: "1 of 2 answered")
        openProgress(app)
        requireLabel(of: attemptsRow(app), containing: "1")
    }

    func testResetLaunchArgumentClearsProgress() throws {
        let app = launchHome()
        try answerOneItemAndEndSession(app)

        app.terminate()
        let fresh = launch(reset: true, name: "ZzTest")

        requireLabel(of: fresh.element(AXID.fixtureScenarioCard), containing: "0 of 2 answered")
        openProgress(fresh)
        requireLabel(of: attemptsRow(fresh), containing: "0")
    }

    func testResetProgressCancelChangesNothing() throws {
        let app = launchHome()
        try answerOneItemAndEndSession(app)
        openSettings(app)

        tap(app.element(AXID.settingsReset), "Reset progress")
        // On iPhone this dialog appears as a popover anchored to the button. It has only the destructive
        // button (no Cancel button); cancelling is a tap outside it, which the system exposes as this region.
        let confirmation = app.sheets["Reset all progress?"]
        requireExists(confirmation, "the reset confirmation")
        let outside = app.otherElements["PopoverDismissRegion"].firstMatch
        requireExists(outside, "the area outside the confirmation")
        outside.tap()

        requireGone(confirmation, "the confirmation")
        XCTAssertFalse(app.staticTexts["Progress was reset."].exists)
        app.navigationBars.buttons.firstMatch.tap()
        requireLabel(of: app.element(AXID.fixtureScenarioCard), containing: "1 of 2 answered")
    }

    func testConfirmedResetClearsProgressButKeepsTheName() throws {
        let app = launchHome()
        try answerOneItemAndEndSession(app)
        openSettings(app)

        tap(app.element(AXID.settingsReset), "Reset progress")
        // The dialog's destructive button shares its title with the Settings button behind it.
        let confirm = app.sheets.buttons["Reset progress"].firstMatch
        requireExists(confirm, "Reset progress in the confirmation")
        confirm.tap()

        requireExists(app.staticTexts["Progress was reset."], "the reset confirmation message")
        XCTAssertTrue(app.staticTexts["ZzTest"].exists, "The name shown in Settings must be unchanged")
        app.navigationBars.buttons.firstMatch.tap()
        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting")
        XCTAssertEqual(greeting.label, "Hi ZzTest")
        requireLabel(of: app.element(AXID.fixtureScenarioCard), containing: "0 of 2 answered")
        openProgress(app)
        requireLabel(of: attemptsRow(app), containing: "0")
    }
}
