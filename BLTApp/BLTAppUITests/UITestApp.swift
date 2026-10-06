import XCTest

/// Accessibility identifiers, copied as literals because this target cannot import the package.
/// Source of truth: Packages/BLTKit/Sources/BLTDesign/AccessibilityID.swift. If a value changes there,
/// change it here too (a stale value shows up as an element that is never found).
enum AXID {
    static let feedbackCorrect = "feedback.correct"
    static let feedbackWrongRegister = "feedback.wrongRegister"
    static let feedbackNotQuite = "feedback.notQuite"
    static let badgeUnreviewed = "badge.unreviewed"
    static let continueButton = "continue.button"
    static let progressRegisterAccuracy = "progress.registerAccuracy"
    static let progressLearned = "progress.learned"
    static let progressDue = "progress.due"
    static let settingsReset = "settings.reset"
    static let endSessionButton = "session.end.button"
    static let endSessionConfirm = "session.end.confirm"
    static let endSessionKeepGoing = "session.end.keepGoing"
    static let introStart = "intro.start"
    static let nameField = "name.field"
    static let nameContinue = "name.continue"
    static let nameError = "name.error"
    static let greeting = "home.greeting"
    static let settingsChangeName = "settings.changeName"
    static let changeNameField = "changeName.field"
    static let changeNameSave = "changeName.save"
    static let changeNameCancel = "changeName.cancel"
    /// Mirrors `AccessibilityID.scenarioCard("zz-scenario")`, the only scenario in the fixture catalog.
    static let fixtureScenarioCard = "scenario.card.zz-scenario"
}

/// The two fake items from PreviewCatalog (Packages/BLTKit/Sources/BLTFeatures/PreviewCatalog.swift).
/// Item order is shuffled per session, so tests branch on the prompt text rather than on position.
struct FixtureQuestion: Equatable {
    let prompt: String
    let canonical: String
    /// The same sentence in the other register; `nil` for the neutral item.
    let otherRegister: String?
    let wrongOptions: [String]
    let isUnreviewed: Bool

    static let respectful = FixtureQuestion(
        prompt: "zz prompt one (to an elder)",
        canonical: "zz canonical one",
        otherRegister: "zz casual one",
        wrongOptions: ["zz wrong one", "zz wrong two"],
        isUnreviewed: true
    )

    static let neutral = FixtureQuestion(
        prompt: "zz prompt two",
        canonical: "zz canonical two",
        otherRegister: nil,
        wrongOptions: ["zz wrong three", "zz wrong four", "zz wrong five"],
        isUnreviewed: false
    )

    static let all = [respectful, neutral]
}

/// Raised by helpers when the screen is not in the state a test needs. The test also records a failure.
struct UITestError: Error {
    let message: String
}

/// Base class: fail fast, launch helpers, and waiting helpers. No fixed sleeps anywhere; every wait
/// is `waitForExistence` or a predicate expectation with a timeout.
@MainActor
class BLTUITestCase: XCTestCase {
    static let timeout: TimeInterval = 10
    static let largestTextSize = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUpWithError() throws {
        // A failed step leaves the app somewhere unexpected, so later steps would only add noise.
        continueAfterFailure = false
    }

    // MARK: Launching

    /// Launches on the fake catalog. `reset` erases the separate UI-test progress and profile files
    /// first (so onboarding shows); `name` seeds a saved profile (so onboarding is skipped).
    func launch(reset: Bool = false, name: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = Self.arguments(reset: reset, name: name, largestText: largestText)
        app.launch()
        return app
    }

    /// Terminates and launches again on the same files, with no reset and no seeding: what a user
    /// closing and reopening the app sees.
    func relaunch(_ app: XCUIApplication, largestText: Bool = false) {
        app.terminate()
        app.launchArguments = Self.arguments(reset: false, name: nil, largestText: largestText)
        app.launch()
    }

    private static func arguments(reset: Bool, name: String?, largestText: Bool) -> [String] {
        var arguments = ["--uitest-fixtures"]
        if reset {
            arguments.append("--uitest-reset")
        }
        if let name {
            arguments.append("--uitest-name=\(name)")
        }
        if largestText {
            arguments += ["-UIPreferredContentSizeCategoryName", largestTextSize]
        }
        return arguments
    }

    /// The common starting point: onboarding skipped, progress empty.
    func launchHome(name: String = "ZzTest", largestText: Bool = false) -> XCUIApplication {
        let app = launch(reset: true, name: name, largestText: largestText)
        requireExists(app.element(AXID.greeting), "Home greeting after launch")
        return app
    }

    // MARK: Waiting

    func requireExists(
        _ element: XCUIElement,
        _ what: String,
        timeout: TimeInterval = BLTUITestCase.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected \(what) to appear", file: file, line: line)
    }

    func requireGone(
        _ element: XCUIElement,
        _ what: String,
        timeout: TimeInterval = BLTUITestCase.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        let result = XCTWaiter().wait(for: [gone], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected \(what) to go away", file: file, line: line)
    }

    /// Waits until the element's accessibility label contains `text` (used for combined elements such as cards).
    func requireLabel(
        of element: XCUIElement,
        containing text: String,
        timeout: TimeInterval = BLTUITestCase.timeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExists(element, "an element whose label contains '\(text)'", timeout: timeout, file: file, line: line)
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let matches = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [matches], timeout: timeout)
        XCTAssertEqual(
            result,
            .completed,
            "Expected label containing '\(text)' but it is '\(element.label)'",
            file: file,
            line: line
        )
    }

    /// The fixture scenario card's completion. The card reads "title, subtitle, N percent complete", so the
    /// match includes the preceding ", " (otherwise "0 percent" would also match "50" and "100").
    func requireCompletion(
        percent: Int,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireLabel(
            of: app.element(AXID.fixtureScenarioCard),
            containing: ", \(percent) percent complete",
            file: file,
            line: line
        )
    }

    func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        requireExists(element, what, file: file, line: line)
        element.tap()
    }

    // MARK: Session flow

    func openFixtureScenario(_ app: XCUIApplication) {
        tap(app.element(AXID.fixtureScenarioCard), "the fixture scenario card")
    }

    /// Reads which fixture item is on a Question screen from its prompt text.
    func currentQuestion(_ app: XCUIApplication) throws -> FixtureQuestion {
        let prompts = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'zz prompt'")).firstMatch
        guard prompts.waitForExistence(timeout: Self.timeout) else {
            XCTFail("No question prompt appeared")
            throw UITestError(message: "No question prompt")
        }
        let label = prompts.label
        guard let question = FixtureQuestion.all.first(where: { $0.prompt == label }) else {
            XCTFail("Unknown prompt '\(label)'")
            throw UITestError(message: "Unknown prompt")
        }
        return question
    }

    /// Taps the option whose visible text is `text` (options have no identifier).
    func choose(_ text: String, in app: XCUIApplication) {
        tap(app.buttons[text], "the option '\(text)'")
    }

    func tapContinue(_ app: XCUIApplication) {
        tap(app.buttons[AXID.continueButton], "the Continue button")
    }

    /// Answers the current question with its canonical option and continues to what follows.
    func answerCorrectlyAndContinue(_ app: XCUIApplication) throws {
        let question = try currentQuestion(app)
        choose(question.canonical, in: app)
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        tapContinue(app)
    }

    /// Answers whatever comes first correctly until `target` is on screen (at most once with two items).
    func advance(_ app: XCUIApplication, toQuestion target: FixtureQuestion) throws {
        for _ in FixtureQuestion.all {
            if try currentQuestion(app) == target {
                return
            }
            try answerCorrectlyAndContinue(app)
        }
        XCTFail("Never reached the question '\(target.prompt)'")
        throw UITestError(message: "Target question not reached")
    }

    func confirmEndSession(_ app: XCUIApplication) {
        tap(app.buttons[AXID.endSessionButton], "the End session control")
        let alert = app.alerts["End this session?"]
        requireExists(alert, "the end-session confirmation")
        // The alert reports each button twice (a nested duplicate), so a plain subscript is ambiguous.
        tap(alert.buttons[AXID.endSessionConfirm].firstMatch, "End session in the confirmation")
        requireExists(app.element(AXID.greeting), "Home after ending the session")
    }
}

extension XCUIApplication {
    /// Any element, of any type, with this accessibility identifier. Combined and custom elements
    /// (cards, feedback, the greeting) do not map to one predictable element type.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
