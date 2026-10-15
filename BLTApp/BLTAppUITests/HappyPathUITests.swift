import XCTest

/// PR tier (DECISIONS 045): one happy path per screen, together with the default-size audits in
/// `AccessibilityUITests`. This is the whole of what a pull request runs through the UI, so a test is added here
/// only when a new screen appears. Rules (what a wrong answer does, what Reset clears, what is saved) are checked
/// in the package, not here; the detailed screen tests are in the other classes and run in the full tier.
@MainActor
final class HappyPathUITests: BLTUITestCase {
    /// Intro, name entry, language step and Home: first launch through to the greeting and the course shown.
    func testOnboardingGoesFromIntroThroughNameAndLanguageToHome() {
        let enteredName = "ZzPerson"
        let app = launchToNameEntry()

        enterName(enteredName, in: app)
        tap(app.element(AXID.nameContinue), "Continue")

        requireExists(app.element(AXID.languageContinue), "the language step")
        XCTAssertFalse(app.element(AXID.greeting).exists, "Home must not show before a language is chosen")
        XCTAssertFalse(app.buttons[AXID.languageContinue].isEnabled, "Continue waits for a choice")
        chooseLanguageAndContinue(.telugu, in: app)

        requireGreetingText("Hi \(enteredName)", in: app)
        requireLabel(of: app.element(AXID.homeLanguage), containing: "Telugu")
        XCTAssertFalse(app.textFields[AXID.nameField].exists)
        XCTAssertFalse(app.element(AXID.languageContinue).exists)
    }

    /// Home: the greeting sits above the Scenarios label, which sits above the first card.
    func testGreetingIsAboveTheScenariosLabel() {
        let app = launchHome()

        // The identifier sits on the greeting's container; the words are its static text child.
        requireGreetingText("Hi ZzTest", in: app)
        let greeting = app.staticTexts["Hi ZzTest"]
        let label = app.staticTexts["Scenarios"]
        requireExists(label, "the Scenarios label")
        XCTAssertLessThanOrEqual(greeting.frame.maxY, label.frame.minY, "The greeting must sit above 'Scenarios'")
        // The fixture lesson has no level, so it is listed under "Other lessons", below the Scenarios label.
        XCTAssertLessThan(label.frame.minY, app.element(AXID.fixtureScenarioCard).frame.minY)
    }

    /// Question, feedback and summary: answer both fixture items, see the summary, and return Home with Done.
    func testFinishedSummaryAppearsAfterLastItemAndDoneReturnsHome() throws {
        let app = launchHome()
        openFixtureScenario(app)

        try answerCorrectlyAndContinue(app)
        XCTAssertFalse(app.staticTexts["Session finished"].exists, "One item is still to come")
        try answerCorrectlyAndContinue(app)

        requireExists(app.staticTexts["Session finished"], "the finished summary")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists, "The summary has its own Done")
        tap(app.buttons["Done"], "Done")
        requireExists(app.element(AXID.greeting), "Home after Done")
        XCTAssertFalse(app.staticTexts["Session finished"].exists)
    }

    /// The End session control: ask, confirm, and arrive back on Home.
    func testConfirmingEndReturnsHome() {
        let app = launchHome()
        openFixtureScenario(app)

        confirmEndSession(app)

        requireExists(app.element(AXID.fixtureScenarioCard), "the scenario card on Home")
        XCTAssertFalse(app.buttons[AXID.endSessionButton].exists)
    }

    /// Settings: the Lessons section offers Import lessons with its helper text.
    func testSettingsOffersImportLessonsWithItsHelperText() {
        let app = launchHome()
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")

        let importButton = app.buttons[AXID.settingsImportLessons]
        requireExists(importButton, "the Import lessons button")
        XCTAssertEqual(importButton.label, "Import lessons")
        requireExists(
            app.staticTexts["Choose lesson files (.json) from the Files app. Your progress is kept."],
            "the Import lessons helper text"
        )
    }

    // MARK: Daily practice (DECISIONS 047)
    // A seeded launch (`--uitest-practice=3`) has a 3 day streak ending yesterday evening, and an app clock fixed
    // to noon today, so these never depend on the hour they run at.

    /// Home: the flame chip shows the seeded streak, above the Today card.
    func testHomeShowsTheSeededStreakOnTheFlameChip() {
        let app = launchHome(extraArguments: [PracticeArguments.streak(3)])

        let chip = app.element(AXID.homeStreakChip)
        requireLabel(of: chip, containing: "3 day streak")
        requireExists(app.element(AXID.homeTodayCard), "the Today card")
        XCTAssertLessThan(chip.frame.minY, app.element(AXID.homeTodayCard).frame.minY, "The chip sits above the card")
    }

    /// Session end and Home: finishing a session grows the streak, shows the streak block on the summary, and the
    /// new count is on the chip when Home returns.
    func testFinishingASessionGrowsTheStreakAndShowsItOnTheSummary() throws {
        let app = launchHome(extraArguments: [PracticeArguments.streak(3)])

        try finishFixtureSession(app)

        requireLabel(of: app.element(AXID.sessionStreak), containing: "4 day streak")
        tap(app.buttons["Done"], "Done")
        requireExists(app.element(AXID.greeting), "Home after Done")
        requireLabel(of: app.element(AXID.homeStreakChip), containing: "4 day streak")
    }

    /// The streak screen: opens from the chip with the count and the deadline in words; Done returns to Home.
    func testStreakScreenOpensFromTheChipAndDoneReturnsHome() {
        let app = launchHome(extraArguments: [PracticeArguments.streak(3)])

        tap(app.element(AXID.homeStreakChip), "the flame chip")

        requireExists(app.element(AXID.streakScreen), "the streak screen")
        requireLabel(of: app.element(AXID.streakCount), containing: "3 day streak")
        // The last session was yesterday at 6 pm, the clock says noon: the deadline is 6 pm today.
        requireLabel(of: app.element(AXID.streakDeadline), containing: "Practise by")
        requireLabel(of: app.element(AXID.streakDeadline), containing: "today")
        tap(app.buttons[AXID.streakDone], "Done on the streak screen")
        requireExists(app.element(AXID.greeting), "Home after Done")
        requireGone(app.element(AXID.streakScreen), "the streak screen")
    }
}
