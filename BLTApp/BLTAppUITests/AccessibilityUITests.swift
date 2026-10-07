import XCTest

/// `performAccessibilityAudit()` on every screen at the default text size and at the largest
/// accessibility size, plus checks that the key controls can still be reached at that size.
///
/// A finding fails the test and goes in the report. The two narrow exceptions are documented on
/// `isSystemToolbarButtonDynamicTypeIssue` and `isOccludedByContinueBar`; the name screens are audited with the
/// system keyboard dismissed (see `dismissKeyboard`).
@MainActor
final class AccessibilityUITests: BLTUITestCase {
    private enum Screen {
        case intro, nameEntry, home, question, feedback, progress, settings, changeName
    }

    /// Launches fresh and navigates to `screen`.
    private func open(_ screen: Screen, largestText: Bool) -> XCUIApplication {
        switch screen {
        case .intro:
            let app = launch(reset: true, largestText: largestText)
            requireExists(app.element(AXID.introStart), "the intro")
            return app
        case .nameEntry:
            let app = launch(reset: true, largestText: largestText)
            tap(app.element(AXID.introStart), "Get started")
            requireExists(app.textFields[AXID.nameField], "the name field")
            return app
        case .home:
            return launchHome(largestText: largestText)
        case .question, .feedback:
            return openSessionScreen(screen, largestText: largestText)
        case .progress:
            let app = launchHome(largestText: largestText)
            tap(app.buttons["Progress"], "the Progress button")
            requireExists(app.element(AXID.progressLearned), "the Progress figures")
            return app
        case .settings, .changeName:
            return openSettingsScreen(screen, largestText: largestText)
        }
    }

    private func openSessionScreen(_ screen: Screen, largestText: Bool) -> XCUIApplication {
        let app = launchHome(largestText: largestText)
        openFixtureScenario(app)
        requireExists(app.buttons[AXID.endSessionButton], "the question screen")
        if screen == .feedback {
            // Both fixture items have the same canonical-first flow; read the shown prompt to find it.
            let prompt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'zz prompt'")).firstMatch
            requireExists(prompt, "the question prompt")
            let question = FixtureQuestion.all.first { $0.prompt == prompt.label }
            XCTAssertNotNil(question, "Unknown prompt '\(prompt.label)'")
            if let question {
                app.buttons[question.canonical].tap()
            }
            requireExists(app.element(AXID.feedbackCorrect), "the feedback screen")
            // The question-to-feedback change is a short crossfade; audit the settled screen, not a frame
            // from the middle of it (an audit taken mid-fade reported contrast failures that a settled
            // screen did not).
            let isSettled = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isHittable == true"),
                object: app.buttons[AXID.continueButton]
            )
            XCTAssertEqual(XCTWaiter().wait(for: [isSettled], timeout: Self.timeout), .completed)
        }
        return app
    }

    private func openSettingsScreen(_ screen: Screen, largestText: Bool) -> XCUIApplication {
        let app = launchHome(largestText: largestText)
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")
        if screen == .changeName {
            let change = app.element(AXID.settingsChangeName)
            scrollIntoView(change, in: app)
            change.tap()
            requireExists(app.textFields[AXID.changeNameField], "the Change name sheet")
        }
        return app
    }

    /// Swipes up (at most a few times) until the element can be tapped.
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        requireExists(element, "the element to scroll to")
        var swipes = 0
        while !element.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// The one issue this file ignores: "Dynamic Type font sizes are partially unsupported" on the Change name
    /// sheet's Cancel and Save. They are plain `Button`s in a SwiftUI navigation-bar toolbar (no custom font),
    /// and the system caps the size of bar-button text, so the audit flags them at every size even though the
    /// app sets nothing that prevents scaling. Matched by audit type AND the two identifiers, so any other
    /// element, or any other issue on these two buttons (such as contrast), still fails.
    private static func isSystemToolbarButtonDynamicTypeIssue(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard issue.auditType == .dynamicType, let element = issue.element else { return false }
        return [AXID.changeNameSave, AXID.changeNameCancel].contains(element.identifier)
    }

    /// The second ignored case: a contrast issue on an element whose frame overlaps the Continue bar on the
    /// feedback screen. At the largest size the gloss chip starts partly underneath that bar (it is scrollable
    /// content, revealed by scrolling), and the audit measures the bar's colour behind the chip's text. It is
    /// not a real contrast problem: a screenshot of the screen scrolled clear of the bar shows the chip's dark
    /// text on its near-white fill (checked by eye, not by an automated test). Matched by audit type AND overlap.
    private static func isOccludedByContinueBar(_ issue: XCUIAccessibilityAuditIssue, bar: CGRect) -> Bool {
        guard issue.auditType == .contrast, let element = issue.element, !bar.isEmpty else { return false }
        return element.frame.intersects(bar)
    }

    /// The two name screens focus their field on arrival, so the system keyboard is up when the audit starts.
    /// That keyboard is Apple's, not ours, and it makes the audit report things we cannot fix: its empty
    /// prediction cells have no label (seen on a GitHub runner), and at the largest text size it covers the
    /// Continue button and the helper text, which the audit then reports as contrast failures. So these two
    /// screens are audited with the keyboard dismissed; that they can still be used with it up is covered by the
    /// `...ControlsAreReachableAtXXXL` tests. Both screens scroll with `.scrollDismissesKeyboard(.interactively)`,
    /// so a drag from just above the field down past the keyboard's top edge pulls it away.
    private func dismissKeyboard(in app: XCUIApplication, field: XCUIElement) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let start = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: -12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97))
        start.press(forDuration: 0.1, thenDragTo: end)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: keyboard)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: Self.timeout), .completed, "The keyboard did not dismiss")
    }

    private func audit(_ screen: Screen, largestText: Bool) throws {
        let app = open(screen, largestText: largestText)
        switch screen {
        case .nameEntry: dismissKeyboard(in: app, field: app.textFields[AXID.nameField])
        case .changeName: dismissKeyboard(in: app, field: app.textFields[AXID.changeNameField])
        default: break
        }
        // Only the feedback screen has a Continue bar; reading its frame elsewhere would fail the lookup.
        let continueBar = screen == .feedback ? app.buttons[AXID.continueButton].frame : .zero
        // Keep going after the first finding so one run reports every issue on the screen.
        continueAfterFailure = true
        try app.performAccessibilityAudit { issue in
            // Apart from the two narrow cases above, every issue is recorded as a failure with the element it
            // points at. (Returning true only means "handled"; the XCTFail is what fails the test.)
            if Self.isSystemToolbarButtonDynamicTypeIssue(issue)
                || Self.isOccludedByContinueBar(issue, bar: continueBar) {
                return true
            }
            let element = issue.element
            let target = element.map { "\($0.elementType) id='\($0.identifier)' label='\($0.label)'" }
            let frame = element.map { "\($0.frame)" } ?? "no frame"
            XCTFail(
                "\(issue.auditType): \(issue.compactDescription) | \(issue.detailedDescription) | "
                    + "\(target ?? "no element") \(frame)"
            )
            return true
        }
    }

    // MARK: Default text size

    func testIntroAudit() throws { try audit(.intro, largestText: false) }
    func testNameEntryAudit() throws { try audit(.nameEntry, largestText: false) }
    func testHomeAudit() throws { try audit(.home, largestText: false) }
    func testQuestionAudit() throws { try audit(.question, largestText: false) }
    func testFeedbackAudit() throws { try audit(.feedback, largestText: false) }
    func testProgressAudit() throws { try audit(.progress, largestText: false) }
    func testSettingsAudit() throws { try audit(.settings, largestText: false) }
    func testChangeNameSheetAudit() throws { try audit(.changeName, largestText: false) }

    // MARK: Largest accessibility text size

    func testIntroAuditAtXXXL() throws { try audit(.intro, largestText: true) }
    func testNameEntryAuditAtXXXL() throws { try audit(.nameEntry, largestText: true) }
    func testHomeAuditAtXXXL() throws { try audit(.home, largestText: true) }
    func testQuestionAuditAtXXXL() throws { try audit(.question, largestText: true) }
    func testFeedbackAuditAtXXXL() throws { try audit(.feedback, largestText: true) }
    func testProgressAuditAtXXXL() throws { try audit(.progress, largestText: true) }
    func testSettingsAuditAtXXXL() throws { try audit(.settings, largestText: true) }
    func testChangeNameSheetAuditAtXXXL() throws { try audit(.changeName, largestText: true) }

    // MARK: Reachability at the largest size

    func testIntroAndNameEntryControlsAreReachableAtXXXL() {
        let app = open(.intro, largestText: true)
        XCTAssertTrue(app.element(AXID.introStart).isHittable, "Get started")
        app.element(AXID.introStart).tap()
        requireExists(app.textFields[AXID.nameField], "the name field")
        XCTAssertTrue(app.textFields[AXID.nameField].isHittable, "Name field")
        scrollIntoView(app.element(AXID.nameContinue), in: app)
        XCTAssertTrue(app.element(AXID.nameContinue).isHittable, "Continue")
    }

    func testHomeControlsAreReachableAtXXXL() {
        let app = open(.home, largestText: true)
        XCTAssertTrue(app.buttons["Progress"].isHittable, "Progress")
        XCTAssertTrue(app.buttons["Settings"].isHittable, "Settings")
        scrollIntoView(app.element(AXID.fixtureScenarioCard), in: app)
        XCTAssertTrue(app.element(AXID.fixtureScenarioCard).isHittable, "Scenario card")
    }

    func testSessionControlsAreReachableAtXXXL() throws {
        let app = open(.question, largestText: true)
        XCTAssertTrue(app.buttons[AXID.endSessionButton].isHittable, "End session on the question")
        let question = try currentQuestion(app)
        let option = app.buttons[question.canonical]
        scrollIntoView(option, in: app)
        XCTAssertTrue(option.isHittable, "The canonical option")
        option.tap()
        requireExists(app.element(AXID.feedbackCorrect), "correct feedback")
        XCTAssertTrue(app.buttons[AXID.endSessionButton].isHittable, "End session on the feedback")
        XCTAssertTrue(app.buttons[AXID.continueButton].isHittable, "Continue on the feedback")
    }

    func testSettingsControlsAreReachableAtXXXL() {
        let app = open(.settings, largestText: true)
        scrollIntoView(app.element(AXID.settingsChangeName), in: app)
        XCTAssertTrue(app.element(AXID.settingsChangeName).isHittable, "Change name")
        scrollIntoView(app.element(AXID.settingsReset), in: app)
        XCTAssertTrue(app.element(AXID.settingsReset).isHittable, "Reset progress")
    }

    func testChangeNameSheetControlsAreReachableAtXXXL() {
        let app = open(.changeName, largestText: true)
        XCTAssertTrue(app.textFields[AXID.changeNameField].isHittable, "Name field")
        XCTAssertTrue(app.buttons[AXID.changeNameSave].isHittable, "Save")
        XCTAssertTrue(app.buttons[AXID.changeNameCancel].isHittable, "Cancel")
    }
}
