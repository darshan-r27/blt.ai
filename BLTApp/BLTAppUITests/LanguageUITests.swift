import XCTest

/// The two-course flows that need the real app: choosing a language in onboarding, a profile saved before the
/// language existed, switching language in Settings, and Reset clearing one language. Full tier (DECISIONS 045).
/// The rules behind them are checked in the package (`TwoCoursesStayApartTests`, `OnboardingGateTests`,
/// `SettingsLanguageTests`): that the gate asks and never assumes, that each language has its own progress, and
/// what Reset clears. These tests stay because the whole app is rebuilt on the other course.
@MainActor
final class LanguageUITests: BLTUITestCase {
    // MARK: Helpers

    private func openSettings(_ app: XCUIApplication) {
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")
    }

    /// Settings, then Language I'm learning, the other language and Switch: ends on that language's Home.
    private func switchLanguage(to language: UITestLanguage, in app: XCUIApplication) {
        openSettings(app)
        tap(app.buttons[AXID.settingsLanguage], "the Language I'm learning row")
        tap(app.buttons[AXID.settingsLanguageOption(language)], "the \(language.displayName) option")
        requireExists(app.staticTexts["Switch to \(language.displayName)?"], "the Switch confirmation")
        // The confirmation is an action sheet; its button shares nothing with the screen behind it.
        tap(app.sheets.buttons["Switch"].firstMatch, "Switch in the confirmation")
        requireExists(app.element(AXID.greeting), "Home after switching")
        requireLabel(of: app.element(AXID.homeLanguage), containing: language.displayName)
    }

    /// Answers one item of `language`'s fixture correctly and ends the session, leaving the app on Home.
    private func answerOneItemAndEnd(_ language: UITestLanguage, in app: XCUIApplication) throws {
        openFixtureScenario(app, language: language)
        let question = try currentQuestion(app, language: language)
        choose(question.canonical, in: app)
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        confirmEndSession(app)
        requireCompletion(percent: 50, in: app, language: language)
    }

    // MARK: Onboarding

    func testChoosingALanguageInOnboardingShowsThatCourseOnHome() {
        let app = launch(reset: true)
        tap(app.element(AXID.introStart), "Get started")
        enterName("ZzPerson", in: app)
        tap(app.element(AXID.nameContinue), "Continue")
        requireExists(app.element(AXID.languageContinue), "the language step")

        chooseLanguageAndContinue(.telugu, in: app)

        requireLabel(of: app.element(AXID.homeLanguage), containing: "Telugu")
        requireExists(app.element(AXID.fixtureScenarioCardTelugu), "the Telugu lesson")
        XCTAssertFalse(app.element(AXID.fixtureScenarioCard).exists, "The Tamil lesson must not be listed")
    }

    func testAProfileWithANameAndNoLanguageIsAskedForOneAndKeepsItAfterwards() {
        let app = launchToLanguageStep(name: "ZzOld")
        XCTAssertFalse(app.element(AXID.greeting).exists, "Home must wait for a language")
        XCTAssertFalse(app.buttons[AXID.languageOption(.tamil)].isSelected, "Nothing is assumed")
        XCTAssertFalse(app.buttons[AXID.languageOption(.telugu)].isSelected, "Nothing is assumed")

        chooseLanguageAndContinue(.tamil, in: app)
        requireGreetingText("Hi ZzOld", in: app)

        relaunch(app)
        requireGreetingText("Hi ZzOld", in: app)
        requireLabel(of: app.element(AXID.homeLanguage), containing: "Tamil")
        XCTAssertFalse(app.element(AXID.languageContinue).exists, "The language is not asked again")
    }

    // MARK: Switching

    func testSwitchingLanguageShowsTheOtherCoursesProgressAndComingBackFindsTheFirstUntouched() throws {
        let app = launchHome(language: .tamil)
        try answerOneItemAndEnd(.tamil, in: app)

        switchLanguage(to: .telugu, in: app)
        requireCompletion(percent: 0, in: app, language: .telugu)
        XCTAssertFalse(app.element(AXID.fixtureScenarioCard).exists, "The Tamil lesson must not be listed")

        switchLanguage(to: .tamil, in: app)
        requireCompletion(percent: 50, in: app, language: .tamil)
        XCTAssertFalse(app.element(AXID.fixtureScenarioCardTelugu).exists)
    }

    func testSwitchSurvivesARelaunch() {
        let app = launchHome(language: .tamil)

        switchLanguage(to: .telugu, in: app)
        relaunch(app)

        requireExists(app.element(AXID.greeting), "Home after relaunch")
        requireLabel(of: app.element(AXID.homeLanguage), containing: "Telugu")
    }

    // MARK: Reset

    func testResetClearsOnlyTheCurrentLanguageAndTheConfirmationNamesIt() throws {
        let app = launchHome(language: .tamil)
        try answerOneItemAndEnd(.tamil, in: app)
        switchLanguage(to: .telugu, in: app)
        try answerOneItemAndEnd(.telugu, in: app)
        openSettings(app)

        tap(app.element(AXID.settingsReset), "Reset progress")
        requireExists(app.staticTexts["Reset Telugu progress?"], "the confirmation naming Telugu")
        XCTAssertFalse(app.staticTexts["Reset Tamil progress?"].exists)
        let confirm = app.sheets.buttons["Reset progress"].firstMatch
        requireExists(confirm, "Reset progress in the confirmation")
        confirm.tap()
        requireExists(app.staticTexts["Progress was reset."], "the reset confirmation message")

        app.navigationBars.buttons.firstMatch.tap()
        requireCompletion(percent: 0, in: app, language: .telugu)
        switchLanguage(to: .tamil, in: app)
        requireCompletion(percent: 50, in: app, language: .tamil)
    }
}
