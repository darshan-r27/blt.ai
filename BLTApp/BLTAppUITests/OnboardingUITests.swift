import XCTest

/// First launch: intro, name entry, Home greeting, and the saved name on later launches.
@MainActor
final class OnboardingUITests: BLTUITestCase {
    private let enteredName = "ZzPerson"

    /// Fresh launch, past the intro, on the name entry screen.
    private func launchToNameEntry() -> XCUIApplication {
        let app = launch(reset: true)
        tap(app.element(AXID.introStart), "Get started")
        requireExists(app.textFields[AXID.nameField], "the name field")
        return app
    }

    private func enterName(_ name: String, in app: XCUIApplication) {
        let field = app.textFields[AXID.nameField]
        field.tap()
        field.typeText(name)
    }

    func testFreshLaunchShowsIntro() {
        let app = launch(reset: true)

        requireExists(app.element(AXID.introStart), "the Get started button")
        XCTAssertTrue(app.staticTexts["blt.ai"].exists)
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

    func testEnteringNameProceedsToHomeWithGreeting() {
        let app = launchToNameEntry()

        enterName(enteredName, in: app)
        tap(app.element(AXID.nameContinue), "Continue")

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting")
        requireGreetingText("Hi \(enteredName)", in: app)
        XCTAssertFalse(app.textFields[AXID.nameField].exists)
    }

    func testRelaunchAfterOnboardingGoesStraightToHome() {
        let app = launchToNameEntry()
        enterName(enteredName, in: app)
        tap(app.element(AXID.nameContinue), "Continue")
        requireExists(app.element(AXID.greeting), "the Home greeting")

        relaunch(app)

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting after relaunch")
        requireGreetingText("Hi \(enteredName)", in: app)
        XCTAssertFalse(app.element(AXID.introStart).exists, "Onboarding must not repeat")
    }

    func testSeededNameSkipsOnboarding() {
        let app = launch(reset: true, name: "ZzTest")

        let greeting = app.element(AXID.greeting)
        requireExists(greeting, "the Home greeting")
        requireGreetingText("Hi ZzTest", in: app)
        XCTAssertFalse(app.element(AXID.introStart).exists)
        XCTAssertFalse(app.textFields[AXID.nameField].exists)
    }
}
