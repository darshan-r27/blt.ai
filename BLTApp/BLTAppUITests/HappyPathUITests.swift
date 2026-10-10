import XCTest

/// PR tier (DECISIONS 045): one happy path per screen, together with the default-size audits in
/// `AccessibilityUITests`. This is the whole of what a pull request runs through the UI, so a test is added here
/// only when a new screen appears. Rules (what a wrong answer does, what Reset clears, what is saved) are checked
/// in the package, not here; the detailed screen tests are in the other classes and run in the full tier.
@MainActor
final class HappyPathUITests: BLTUITestCase {
    /// Intro, name entry and Home: first launch through to the greeting.
    func testEnteringNameProceedsToHomeWithGreeting() {
        let enteredName = "ZzPerson"
        let app = launchToNameEntry()

        enterName(enteredName, in: app)
        tap(app.element(AXID.nameContinue), "Continue")

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting")
        requireGreetingText("Hi \(enteredName)", in: app)
        XCTAssertFalse(app.textFields[AXID.nameField].exists)
    }

    /// Home: the greeting sits above the Scenarios label, which sits above the first card.
    func testGreetingIsAboveTheScenariosLabel() {
        let app = launchHome()

        // The identifier sits on the greeting's container; the words are its static text child.
        requireGreetingText("Hi ZzTest", in: app)
        let greeting = app.staticTexts["Hi ZzTest"]
        let label = app.staticTexts["Scenarios"]
        requireExists(label, "the Scenarios label")
        XCTAssertLessThanOrEqual(greeting.frame.maxY, label.frame.minY, "The greeting must sit above 'Scenarios'")
        XCTAssertLessThan(label.frame.minY, app.element(AXID.fixtureScenarioCard).frame.minY)
    }

    /// Question, feedback and summary: answer both fixture items, see the summary, and return Home with Done.
    func testFinishedSummaryAppearsAfterLastItemAndDoneReturnsHome() throws {
        let app = launchHome()
        openFixtureScenario(app)

        try answerCorrectlyAndContinue(app)
        XCTAssertFalse(app.staticTexts["Session finished"].exists, "One item is still to come")
        try answerCorrectlyAndContinue(app)

        requireExists(app.staticTexts["Session finished"], "the finished summary")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists, "The summary has its own Done")
        tap(app.buttons["Done"], "Done")
        requireExists(app.element(AXID.greeting), "Home after Done")
        XCTAssertFalse(app.staticTexts["Session finished"].exists)
    }

    /// The End session control: ask, confirm, and arrive back on Home.
    func testConfirmingEndReturnsHome() {
        let app = launchHome()
        openFixtureScenario(app)

        confirmEndSession(app)

        requireExists(app.element(AXID.fixtureScenarioCard), "the scenario card on Home")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists)
    }

    /// Settings: the Lessons section offers Import lessons with its helper text.
    func testSettingsOffersImportLessonsWithItsHelperText() {
        let app = launchHome()
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")

        let importButton = app.buttons[AXID.settingsImportLessons]
        requireExists(importButton, "the Import lessons button")
        XCTAssertEqual(importButton.label, "Import lessons")
        requireExists(
            app.staticTexts["Choose lesson files (.json) from the Files app. Your progress is kept."],
            "the Import lessons helper text"
        )
    }
}
