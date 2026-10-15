import XCTest

/// Full tier (DECISIONS 045): `performAccessibilityAudit()` on every screen at the largest accessibility text
/// size, plus checks that the key controls can still be reached at that size. These are the slow accessibility
/// checks, so they run on every push to `main`, nightly and on demand, not on each pull request. The default-size
/// audits are in `AccessibilityUITests`. The machinery and the narrow, documented exceptions are in
/// `AccessibilityAuditCase`.
@MainActor
final class AccessibilityLargeTextUITests: AccessibilityAuditCase {
    // MARK: Largest accessibility text size

    func testIntroAuditAtXXXL() throws { try audit(.intro, largestText: true) }
    func testNameEntryAuditAtXXXL() throws { try audit(.nameEntry, largestText: true) }
    func testLanguageStepAuditAtXXXL() throws { try audit(.language, largestText: true) }
    func testLanguageStepWithAChoiceAuditAtXXXL() throws { try audit(.languageChosen, largestText: true) }
    func testHomeAuditAtXXXL() throws { try audit(.home, largestText: true) }
    func testQuestionAuditAtXXXL() throws { try audit(.question, largestText: true) }
    func testFeedbackAuditAtXXXL() throws { try audit(.feedback, largestText: true) }
    func testProgressAuditAtXXXL() throws { try audit(.progress, largestText: true) }
    func testSettingsAuditAtXXXL() throws { try audit(.settings, largestText: true) }
    func testSettingsLanguageChoiceAuditAtXXXL() throws { try audit(.settingsLanguageChoice, largestText: true) }
    func testChangeNameSheetAuditAtXXXL() throws { try audit(.changeName, largestText: true) }

    // Daily practice (DECISIONS 047), with a seeded 3 day streak
    func testHomeWithStreakAuditAtXXXL() throws { try audit(.homeWithStreak, largestText: true) }
    func testSessionSummaryAuditAtXXXL() throws { try audit(.sessionSummary, largestText: true) }
    func testStreakScreenAuditAtXXXL() throws { try audit(.streakScreen, largestText: true) }
    func testSettingsDailyPracticeAuditAtXXXL() throws { try audit(.settingsDailyPractice, largestText: true) }

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

    func testLanguageStepControlsAreReachableAtXXXL() {
        let app = open(.language, largestText: true)
        for language in UITestLanguage.allCases {
            let option = app.buttons[AXID.languageOption(language)]
            scrollIntoView(option, in: app)
            XCTAssertTrue(option.isHittable, "\(language.displayName) option")
        }
        app.buttons[AXID.languageOption(.tamil)].tap()
        scrollIntoView(app.buttons[AXID.languageContinue], in: app)
        XCTAssertTrue(app.buttons[AXID.languageContinue].isHittable, "Continue")
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
        XCTAssertTrue(app.buttons[AXID.settingsLanguage].isHittable, "Language I'm learning")
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

    func testStreakScreenDoneIsReachableAtXXXL() {
        let app = open(.streakScreen, largestText: true)
        scrollIntoView(app.buttons[AXID.streakDone], in: app)
        XCTAssertTrue(app.buttons[AXID.streakDone].isHittable, "Done on the streak screen")
    }

    func testDailyPracticeControlsAreReachableAtXXXL() {
        let app = open(.settingsDailyPractice, largestText: true)
        XCTAssertTrue(app.switches[AXID.settingsReminders].isHittable, "Reminders toggle")
        for identifier in [AXID.settingsQuietHoursStart, AXID.settingsQuietHoursEnd] {
            scrollIntoView(app.element(identifier), in: app)
            XCTAssertTrue(app.element(identifier).isHittable, "Quiet hours picker \(identifier)")
        }
    }
}
