import XCTest

/// Home: greeting above the Scenarios label, and the completion percent on the scenario card.
/// An item counts as complete only when its latest recorded outcome is correct.
@MainActor
final class HomeUITests: BLTUITestCase {
    private func launchSession() -> XCUIApplication {
        let app = launchHome()
        openFixtureScenario(app)
        return app
    }

    func testGreetingIsAboveTheScenariosLabel() {
        let app = launchHome()

        let greeting = app.element(AXID.greeting)
        let label = app.staticTexts["Scenarios"]
        requireExists(label, "the Scenarios label")
        XCTAssertEqual(greeting.label, "Hi ZzTest")
        XCTAssertLessThanOrEqual(greeting.frame.maxY, label.frame.minY, "The greeting must sit above 'Scenarios'")
        XCTAssertLessThan(label.frame.minY, app.element(AXID.fixtureScenarioCard).frame.minY)
    }

    func testCardShowsOnlyCompletionNotTheOldCounts() {
        let app = launchHome()

        requireCompletion(percent: 0, in: app)
        let card = app.element(AXID.fixtureScenarioCard)
        XCTAssertEqual(card.label, "zz scenario, zz subtitle, 0 percent complete")
        let oldLines = NSPredicate(
            format: "label CONTAINS ' due' OR label CONTAINS ' new' OR label CONTAINS 'answered'"
        )
        XCTAssertEqual(app.staticTexts.matching(oldLines).count, 0, "The old count lines must be gone")
        XCTAssertFalse(app.staticTexts["Nothing is due for review right now."].exists)
    }

    func testCorrectAnswersRaiseTheCompletionPercent() throws {
        let app = launchSession()

        try answerCorrectlyAndContinue(app)
        confirmEndSession(app)
        requireCompletion(percent: 50, in: app)

        // The other item is the only unseen one, so the next session asks it.
        openFixtureScenario(app)
        try answerCorrectlyAndContinue(app)
        requireExists(app.staticTexts["Session finished"], "the finished summary")
        tap(app.buttons["Done"], "Done")
        requireCompletion(percent: 100, in: app)
    }

    func testWrongAnswerDoesNotCompleteTheItem() throws {
        let app = launchSession()
        let question = try currentQuestion(app)
        choose(question.wrongOptions[0], in: app)
        requireExists(app.element(AXID.feedbackNotQuite), "not-quite feedback")

        confirmEndSession(app)

        requireCompletion(percent: 0, in: app)
    }

    func testOtherRegisterAnswerDoesNotCompleteTheItem() throws {
        let app = launchSession()
        // If the neutral item comes first it is answered correctly on the way (50%); otherwise nothing is.
        let expectedPercent = try currentQuestion(app) == .respectful ? 0 : 50
        try advance(app, toQuestion: .respectful)
        choose("zz casual one", in: app)
        requireExists(app.element(AXID.feedbackWrongRegister), "wrong-register feedback")

        confirmEndSession(app)

        requireCompletion(percent: expectedPercent, in: app)
    }

    func testMissedItemAskedAgainStaysIncompleteAfterTheSessionFinishes() throws {
        let app = launchSession()
        let missed = try currentQuestion(app)
        choose(missed.wrongOptions[0], in: app)
        requireExists(app.element(AXID.feedbackNotQuite), "not-quite feedback")
        tapContinue(app)
        try answerCorrectlyAndContinue(app)

        // The missed item comes back and is answered correctly, but only the first attempt is recorded.
        XCTAssertEqual(try currentQuestion(app), missed)
        try answerCorrectlyAndContinue(app)
        requireExists(app.staticTexts["Session finished"], "the finished summary")
        tap(app.buttons["Done"], "Done")

        requireCompletion(percent: 50, in: app)
    }
}
