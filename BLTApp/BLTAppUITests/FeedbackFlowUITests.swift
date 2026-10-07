import XCTest

/// The question, feedback and summary beats of a session on the fake catalog (two items, shuffled).
@MainActor
final class FeedbackFlowUITests: BLTUITestCase {
    private func launchSession() -> XCUIApplication {
        let app = launchHome()
        openFixtureScenario(app)
        return app
    }

    func testCanonicalOptionReachesCorrectFeedback() throws {
        let app = launchSession()
        let question = try currentQuestion(app)

        choose(question.canonical, in: app)

        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        XCTAssertFalse(app.element(AXID.feedbackWrongRegister).exists)
        XCTAssertFalse(app.element(AXID.feedbackNotQuite).exists)
    }

    func testOtherRegisterOptionReachesWrongRegisterFeedback() throws {
        let app = launchSession()
        try advance(app, toQuestion: .respectful)

        choose("zz casual one", in: app)

        requireExists(app.element(AXID.feedbackWrongRegister), "wrong-register feedback")
        XCTAssertFalse(app.element(AXID.feedbackCorrect).exists)
        XCTAssertFalse(app.element(AXID.feedbackNotQuite).exists)
    }

    func testWrongOptionReachesNotQuiteFeedback() throws {
        let app = launchSession()
        let question = try currentQuestion(app)

        choose(question.wrongOptions[0], in: app)

        requireExists(app.element(AXID.feedbackNotQuite), "not-quite feedback")
        XCTAssertFalse(app.element(AXID.feedbackCorrect).exists)
        XCTAssertFalse(app.element(AXID.feedbackWrongRegister).exists)
    }

    func testWrongItemReappearsLaterInTheSameSession() throws {
        let app = launchSession()
        let missed = try currentQuestion(app)
        choose(missed.wrongOptions[0], in: app)
        requireExists(app.element(AXID.feedbackNotQuite), "not-quite feedback")
        tapContinue(app)

        // The other item comes next, then the missed one again, before the session can finish.
        let other = try currentQuestion(app)
        XCTAssertNotEqual(other, missed)
        try answerCorrectlyAndContinue(app)
        XCTAssertFalse(app.staticTexts["Session finished"].exists, "The session must not finish with a missed item")
        let again = try currentQuestion(app)
        XCTAssertEqual(again, missed, "The missed item must be asked again")
    }

    func testUnreviewedBadgeShowsOnUnreviewedItemOnlyOnQuestionAndFeedback() throws {
        let app = launchSession()

        for _ in FixtureQuestion.all {
            let question = try currentQuestion(app)
            let badge = app.element(AXID.badgeUnreviewed)
            XCTAssertEqual(badge.exists, question.isUnreviewed, "Badge on question '\(question.prompt)'")
            choose(question.canonical, in: app)
            requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
            XCTAssertEqual(badge.exists, question.isUnreviewed, "Badge on feedback for '\(question.prompt)'")
            tapContinue(app)
        }
    }

    func testFinishedSummaryAppearsAfterLastItemAndDoneReturnsHome() throws {
        let app = launchSession()

        try answerCorrectlyAndContinue(app)
        XCTAssertFalse(app.staticTexts["Session finished"].exists, "One item is still to come")
        try answerCorrectlyAndContinue(app)

        requireExists(app.staticTexts["Session finished"], "the finished summary")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists, "The summary has its own Done")
        tap(app.buttons["Done"], "Done")
        requireExists(app.element(AXID.greeting), "Home after Done")
        XCTAssertFalse(app.staticTexts["Session finished"].exists)
    }
}
