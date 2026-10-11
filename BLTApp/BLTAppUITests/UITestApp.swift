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
    static let settingsImportLessons = "settings.importLessons"
    static let settingsRemoveImported = "settings.removeImported"
    static let settingsImportStatus = "settings.importStatus"
    static let languageContinue = "language.continue"
    static let homeLanguage = "home.language"
    static let homeContinueLesson = "home.continueLesson"
    static let homeOtherLessons = "home.otherLessons"
    static let settingsLanguage = "settings.language"
    static let settingsLanguageConfirm = "settings.language.confirm"
    static let settingsLanguageCancel = "settings.language.cancel"
    /// Mirrors `AccessibilityID.scenarioCard("zz-scenario")`, the only scenario in the Tamil fixture catalog.
    static let fixtureScenarioCard = "scenario.card.zz-scenario"
    /// Mirrors `AccessibilityID.scenarioCard("zz-scenario-telugu")`, the only scenario in the Telugu fixture.
    static let fixtureScenarioCardTelugu = "scenario.card.zz-scenario-telugu"

    static func languageOption(_ language: UITestLanguage) -> String {
        "language.option.\(language.rawValue)"
    }

    static func settingsLanguageOption(_ language: UITestLanguage) -> String {
        "settings.language.option.\(language.rawValue)"
    }

    static func fixtureCard(_ language: UITestLanguage) -> String {
        language == .tamil ? fixtureScenarioCard : fixtureScenarioCardTelugu
    }
}

/// The two courses, as the launch argument `--uitest-language=<raw value>` and the screens spell them.
enum UITestLanguage: String, CaseIterable {
    case tamil
    case telugu

    var displayName: String {
        switch self {
        case .tamil: "Tamil"
        case .telugu: "Telugu"
        }
    }

    var other: UITestLanguage { self == .tamil ? .telugu : .tamil }
}

/// The two fake items of each course's fixture in PreviewCatalog
/// (Packages/BLTKit/Sources/BLTFeatures/PreviewCatalog.swift).
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

    static let teluguRespectful = FixtureQuestion(
        prompt: "zz telugu prompt one (to an elder)",
        canonical: "zz telugu canonical one",
        otherRegister: "zz telugu casual one",
        wrongOptions: ["zz telugu wrong one", "zz telugu wrong two"],
        isUnreviewed: true
    )

    static let teluguNeutral = FixtureQuestion(
        prompt: "zz telugu prompt two",
        canonical: "zz telugu canonical two",
        otherRegister: nil,
        wrongOptions: ["zz telugu wrong three", "zz telugu wrong four", "zz telugu wrong five"],
        isUnreviewed: false
    )

    static func all(_ language: UITestLanguage) -> [FixtureQuestion] {
        language == .tamil ? all : [teluguRespectful, teluguNeutral]
    }

    /// The prefix every prompt of the course's fixture starts with.
    static func promptPrefix(_ language: UITestLanguage) -> String {
        language == .tamil ? "zz prompt" : "zz telugu prompt"
    }
}

/// Raised by helpers when the screen is not in the state a test needs. The test also records a failure.
struct UITestError: Error {
    let message: String
}

/// Base class: fail fast, launch helpers, and waiting helpers. No fixed sleeps anywhere; every wait
/// is `waitForExistence` or a predicate expectation with a timeout.
@MainActor
class BLTUITestCase: XCTestCase {
    static let timeout: TimeInterval = 20
    static let largestTextSize = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUpWithError() throws {
        // A failed step leaves the app somewhere unexpected, so later steps would only add noise.
        continueAfterFailure = false
    }

    // MARK: Launching

    /// Launches on the fake catalog. `reset` erases the separate UI-test progress and profile files
    /// first (so onboarding shows); `name` seeds a saved profile (so the name step is skipped); `language`
    /// seeds the learning language too (so the language step is skipped as well). A name with no language is
    /// a profile saved before the language existed, which the app must ask a language for.
    func launch(
        reset: Bool = false,
        name: String? = nil,
        language: UITestLanguage? = nil,
        largestText: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = Self.arguments(reset: reset, name: name, language: language, largestText: largestText)
        app.launch()
        return app
    }

    /// Terminates and launches again on the same files, with no reset and no seeding: what a user
    /// closing and reopening the app sees.
    func relaunch(_ app: XCUIApplication, largestText: Bool = false) {
        app.terminate()
        app.launchArguments = Self.arguments(reset: false, name: nil, language: nil, largestText: largestText)
        app.launch()
    }

    private static func arguments(
        reset: Bool,
        name: String?,
        language: UITestLanguage?,
        largestText: Bool
    ) -> [String] {
        var arguments = ["--uitest-fixtures"]
        if reset {
            arguments.append("--uitest-reset")
        }
        if let name {
            arguments.append("--uitest-name=\(name)")
        }
        if let language {
            arguments.append("--uitest-language=\(language.rawValue)")
        }
        if largestText {
            arguments += ["-UIPreferredContentSizeCategoryName", largestTextSize]
        }
        return arguments
    }

    /// The common starting point: onboarding skipped (name and language seeded), progress empty. The tests that
    /// are not about a language use the Tamil fixture; the app itself never assumes one.
    func launchHome(
        name: String = "ZzTest",
        language: UITestLanguage = .tamil,
        largestText: Bool = false
    ) -> XCUIApplication {
        let app = launch(reset: true, name: name, language: language, largestText: largestText)
        requireExists(app.element(AXID.greeting), "Home greeting after launch")
        return app
    }

    /// Fresh launch with a saved name and no language (a profile from before the language existed), on the
    /// language step.
    func launchToLanguageStep(name: String = "ZzTest", largestText: Bool = false) -> XCUIApplication {
        let app = launch(reset: true, name: name, largestText: largestText)
        requireExists(app.element(AXID.languageContinue), "the language step")
        return app
    }

    /// Picks `language` on the language step and continues to Home.
    func chooseLanguageAndContinue(_ language: UITestLanguage, in app: XCUIApplication) {
        tap(app.buttons[AXID.languageOption(language)], "the \(language.displayName) option")
        tap(app.buttons[AXID.languageContinue], "Continue on the language step")
        requireExists(app.element(AXID.greeting), "the Home greeting")
    }

    /// Fresh launch, past the intro, on the name entry screen.
    func launchToNameEntry() -> XCUIApplication {
        let app = launch(reset: true)
        tap(app.element(AXID.introStart), "Get started")
        requireExists(app.textFields[AXID.nameField], "the name field")
        return app
    }

    func enterName(_ name: String, in app: XCUIApplication) {
        let field = app.textFields[AXID.nameField]
        field.tap()
        field.typeText(name)
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
        language: UITestLanguage = .tamil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireLabel(
            of: app.element(AXID.fixtureCard(language)),
            containing: ", \(percent) percent complete",
            file: file,
            line: line
        )
    }

    /// The Home greeting: its identifier is on a container, so the words are read from the static text inside it.
    func requireGreetingText(
        _ text: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExists(app.element(AXID.greeting), "the Home greeting", file: file, line: line)
        requireExists(app.staticTexts[text], "the greeting text '\(text)'", file: file, line: line)
    }

    func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        requireExists(element, what, file: file, line: line)
        element.tap()
    }

    // MARK: Session flow

    func openFixtureScenario(_ app: XCUIApplication, language: UITestLanguage = .tamil) {
        tap(app.element(AXID.fixtureCard(language)), "the \(language.displayName) fixture scenario card")
    }

    /// Reads which fixture item is on a Question screen from its prompt text.
    func currentQuestion(_ app: XCUIApplication, language: UITestLanguage = .tamil) throws -> FixtureQuestion {
        let prefix = FixtureQuestion.promptPrefix(language)
        let prompts = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        guard prompts.waitForExistence(timeout: Self.timeout) else {
            XCTFail("No question prompt appeared")
            throw UITestError(message: "No question prompt")
        }
        let label = prompts.label
        guard let question = FixtureQuestion.all(language).first(where: { $0.prompt == label }) else {
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
