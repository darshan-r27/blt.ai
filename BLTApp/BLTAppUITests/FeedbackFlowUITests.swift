import XCTest

/// The feedback screens for the two answers that are not simply correct, and the unreviewed badge, full tier
/// (DECISIONS 045). The correct-answer and summary happy path is in `HappyPathUITests`; which option leads to which
/// feedback, and that a missed item comes back, are checked in the package (`SessionCompletionFlowTests`,
/// `SessionViewModelTests`, `FeedbackRoutingTests`). These tests stay because the screen itself is under test: the
/// right feedback view with the right identifier on screen.
@MainActor
final class FeedbackFlowUITests: BLTUITestCase {
    private func launchSession() -> XCUIApplication {
        let app = launchHome()
        openFixtureScenario(app)
        return app
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
}
