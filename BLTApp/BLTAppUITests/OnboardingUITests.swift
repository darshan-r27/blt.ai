import XCTest

/// First launch details: the intro, the route to name entry, the empty-name error, the language step, and the
/// saved name and language on later launches. Full tier (DECISIONS 045). The whole first-launch path is the happy
/// path in `HappyPathUITests`; the name rules (validation, saving) and the gate rules (a profile with no language
/// is asked, never assumed) are checked in the package.
@MainActor
final class OnboardingUITests: BLTUITestCase {
    private let enteredName = "ZzPerson"

    func testFreshLaunchShowsIntro() {
        let app = launch(reset: true)

        requireExists(app.element(AXID.introStart), "the Get started button")
        XCTAssertTrue(app.staticTexts["B L T dot A I"].exists)
        XCTAssertFalse(app.element(AXID.greeting).exists, "Home must not show before a name is saved")
    }

    func testGetStartedLeadsToNameEntry() {
        let app = launch(reset: true)

        tap(app.element(AXID.introStart), "Get started")

        requireExists(app.textFields[AXID.nameField], "the name field")
        requireExists(app.element(AXID.nameContinue), "the Continue button")
        XCTAssertTrue(app.staticTexts["What should we call you?"].exists)
        XCTAssertFalse(app.element(AXID.introStart).exists)
    }

    func testContinueWithEmptyNameShowsErrorAndStays() {
        let app = launchToNameEntry()

        tap(app.element(AXID.nameContinue), "Continue")

        let error = app.element(AXID.nameError)
        requireExists(error, "the name error message")
        XCTAssertTrue(error.label.contains("Please enter a name."), "Unexpected message: '\(error.label)'")
        XCTAssertTrue(app.textFields[AXID.nameField].exists, "Must stay on name entry")
        XCTAssertFalse(app.element(AXID.greeting).exists, "Must not reach Home without a name")
    }

    func testNameLeadsToTheLanguageStepWithBothCoursesAndNoPreselection() {
        let app = launchToNameEntry()
        enterName(enteredName, in: app)

        tap(app.element(AXID.nameContinue), "Continue")

        requireExists(app.element(AXID.languageContinue), "the language step")
        XCTAssertTrue(app.staticTexts["Which language do you want to learn?"].exists)
        for language in UITestLanguage.allCases {
            XCTAssertTrue(app.buttons[AXID.languageOption(language)].exists, "\(language.displayName) option")
            XCTAssertFalse(
                app.buttons[AXID.languageOption(language)].isSelected,
                "No language may be preselected: nothing defaults to Tamil"
            )
        }
        XCTAssertFalse(app.buttons[AXID.languageContinue].isEnabled)
        XCTAssertFalse(app.element(AXID.greeting).exists, "Must not reach Home without a language")
    }

    func testRelaunchAfterOnboardingGoesStraightToHome() {
        let app = launchToNameEntry()
        enterName(enteredName, in: app)
        tap(app.element(AXID.nameContinue), "Continue")
        chooseLanguageAndContinue(.tamil, in: app)

        relaunch(app)

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting after relaunch")
        requireGreetingText("Hi \(enteredName)", in: app)
        requireLabel(of: app.element(AXID.homeLanguage), containing: "Tamil")
        XCTAssertFalse(app.element(AXID.introStart).exists, "Onboarding must not repeat")
        XCTAssertFalse(app.element(AXID.languageContinue).exists, "The language is not asked again")
    }
}
