import XCTest

/// The always-visible End session control, its confirmation, and what ending does to saved answers.
@MainActor
final class EndSessionUITests: BLTUITestCase {
    private func launchSession() -> XCUIApplication {
        let app = launchHome()
        openFixtureScenario(app)
        return app
    }

    func testEndControlIsVisibleOnQuestionAndFeedback() throws {
        let app = launchSession()
        let question = try currentQuestion(app)
        requireExists(app.buttons[AXID.endSessionButton], "End session on the question")
        XCTAssertTrue(app.buttons[AXID.endSessionButton].isHittable)

        choose(question.canonical, in: app)

        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        requireExists(app.buttons[AXID.endSessionButton], "End session on the feedback")
        XCTAssertTrue(app.buttons[AXID.endSessionButton].isHittable)
    }

    func testEndControlShowsConfirmation() {
        let app = launchSession()

        tap(app.buttons[AXID.endSessionButton], "End session")

        let alert = app.alerts["End this session?"]
        requireExists(alert, "the confirmation")
        XCTAssertTrue(alert.buttons[AXID.endSessionConfirm].firstMatch.exists)
        XCTAssertTrue(alert.buttons[AXID.endSessionKeepGoing].firstMatch.exists)
    }

    func testKeepGoingResumesTheSameQuestion() throws {
        let app = launchSession()
        let question = try currentQuestion(app)
        tap(app.buttons[AXID.endSessionButton], "End session")
        let alert = app.alerts["End this session?"]
        requireExists(alert, "the confirmation")

        tap(alert.buttons[AXID.endSessionKeepGoing].firstMatch, "Keep going")

        requireGone(alert, "the confirmation")
        XCTAssertEqual(try currentQuestion(app), question, "Keep going must not change the question")
        XCTAssertTrue(app.buttons[question.canonical].exists, "The options must still be there")
        XCTAssertTrue(app.buttons[AXID.endSessionButton].isHittable, "Must still be in the session")
    }

    func testConfirmingEndReturnsHome() {
        let app = launchSession()

        confirmEndSession(app)

        requireExists(app.element(AXID.fixtureScenarioCard), "the scenario card on Home")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists)
    }

    func testAnswerGivenBeforeEndingIsCounted() throws {
        let app = launchSession()
        let question = try currentQuestion(app)
        choose(question.canonical, in: app)
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")

        confirmEndSession(app)

        requireCompletion(percent: 50, in: app)
    }
}
