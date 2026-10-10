import XCTest

/// The shared machinery of the accessibility tests: opening each screen, `performAccessibilityAudit()` on it,
/// and scrolling a control into reach. It has no tests of its own. The tests live in two subclasses, one per
/// tier (DECISIONS 045): `AccessibilityUITests` (default text size, on every pull request) and
/// `AccessibilityLargeTextUITests` (the largest accessibility size, on `main`, nightly and on demand). Nothing
/// is dropped by that split; a check only runs in the tier named for it.
///
/// A finding fails the test and goes in the report. The three narrow exceptions are documented on
/// `isSystemToolbarButtonDynamicTypeIssue`, `isOccludedByContinueBar` and `isSettingsTextBehindSheet`; the name
/// screens are audited with the system keyboard dismissed (see `dismissKeyboard`).
@MainActor
class AccessibilityAuditCase: BLTUITestCase {
    enum Screen {
        case intro, nameEntry, language, home, question, feedback, progress, settings, settingsLanguageChoice
        case changeName
    }

    /// Launches fresh and navigates to `screen`.
    func open(_ screen: Screen, largestText: Bool) -> XCUIApplication {
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
        case .language:
            return launchToLanguageStep(largestText: largestText)
        case .home:
            return launchHome(largestText: largestText)
        case .question, .feedback:
            return openSessionScreen(screen, largestText: largestText)
        case .progress:
            let app = launchHome(largestText: largestText)
            tap(app.buttons["Progress"], "the Progress button")
            requireExists(app.element(AXID.progressLearned), "the Progress figures")
            return app
        case .settings, .settingsLanguageChoice, .changeName:
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
        if screen == .settingsLanguageChoice {
            // The row with the two languages shown under it, as a learner sees it while choosing.
            tap(app.buttons[AXID.settingsLanguage], "the Language I'm learning row")
            requireExists(app.buttons[AXID.settingsLanguageOption(.telugu)], "the language options")
        }
        if screen == .changeName {
            let change = app.element(AXID.settingsChangeName)
            scrollIntoView(change, in: app)
            change.tap()
            requireExists(app.textFields[AXID.changeNameField], "the Change name sheet")
        }
        return app
    }

    /// Swipes up (at most a few times) until the element can be tapped.
    func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
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

    /// The third ignored case: on the Change name sheet, a contrast issue on the Settings screen's "About the
    /// content" text, which sits behind the sheet. The audit still walks the screen underneath a sheet, and the
    /// text is hidden by the sheet, so the audit finds no text pixels to measure. On GitHub's runner it reports
    /// this on some runs and not others, on the same build (never seen locally on a clean simulator). It is not
    /// part of the sheet and VoiceOver cannot focus it while the sheet is up; the same text is audited on its own
    /// screen by `testSettingsAudit` and `testSettingsAuditAtXXXL`. Matched by audit type AND the text's two
    /// possible openings (see `SettingsViewModel.contentStatement`), and only when auditing the Change name sheet.
    private static func isSettingsTextBehindSheet(_ issue: XCUIAccessibilityAuditIssue, onSheet: Bool) -> Bool {
        guard onSheet, issue.auditType == .contrast, let label = issue.element?.label else { return false }
        return label.hasPrefix("These lessons were drafted") || label.hasPrefix("Every lesson was checked")
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

    func audit(_ screen: Screen, largestText: Bool) throws {
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
        let handleIssue: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            // Apart from the three narrow cases above, every issue is recorded as a failure with the element it
            // points at. (Returning true only means "handled"; the XCTFail is what fails the test.)
            if Self.isSystemToolbarButtonDynamicTypeIssue(issue)
                || Self.isOccludedByContinueBar(issue, bar: continueBar)
                || Self.isSettingsTextBehindSheet(issue, onSheet: screen == .changeName) {
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
        do {
            try app.performAccessibilityAudit(handleIssue)
        } catch let error as NSError where Self.isAuditTimeout(error) {
            // On a loaded runner the audit of the Change name sheet can run out of its own time limit (it took 80
            // to 100 seconds there). That is the audit tool giving up, not a finding, so it gets one more attempt;
            // a second timeout fails the test.
            try app.performAccessibilityAudit(handleIssue)
        }
    }

    /// "Audit failed to complete in time" (domain `com.apple.xcode.xctest.accessibilityAudit`, code -56).
    private static func isAuditTimeout(_ error: NSError) -> Bool {
        error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56
    }
}
