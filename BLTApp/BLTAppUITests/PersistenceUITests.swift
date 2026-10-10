import XCTest

/// Full tier (DECISIONS 045): the two flows that need the real app process. Answers survive a terminate and
/// relaunch, and confirming Reset progress in Settings clears them through the real dialog. The rules behind both
/// (what is saved, what Reset clears and keeps, that cancelling changes nothing) are checked in the package, in
/// `ProgressSurvivesAndResetsFlowTests` and `ProgressReopenTests`.
@MainActor
final class PersistenceUITests: BLTUITestCase {
    /// Answers one item correctly and ends the session, leaving the app on Home.
    private func answerOneItemAndEndSession(_ app: XCUIApplication) throws {
        openFixtureScenario(app)
        let question = try currentQuestion(app)
        choose(question.canonical, in: app)
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        confirmEndSession(app)
        requireCompletion(percent: 50, in: app)
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
        requireGreetingText("Hi ZzTest", in: app)
        requireCompletion(percent: 50, in: app)
        openProgress(app)
        requireLabel(of: attemptsRow(app), containing: "1")
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
        requireGreetingText("Hi ZzTest", in: app)
        requireCompletion(percent: 0, in: app)
        openProgress(app)
        requireLabel(of: attemptsRow(app), containing: "0")
    }
}
