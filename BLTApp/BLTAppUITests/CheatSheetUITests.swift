import XCTest

/// Cheat sheets, full tier (DECISIONS 048): a topic still in progress has no button, the list of every topic, Reset
/// progress clearing the unlocks, and one record per language. What unlocks a sheet, what a sheet lists and when it
/// stays open after a slip are checked in the package; these tests stay because the screens and the whole-app
/// wiring are what is under test. The PR-tier happy path is in `HappyPathUITests`, the audits in
/// `AccessibilityCheatSheetUITests`.
///
/// The fixture topic has one word, `zz`, whose meaning is `zz gloss`. A launch argument marks the topic complete,
/// so no test answers questions to get a sheet.
@MainActor
final class CheatSheetUITests: BLTUITestCase {
    private var topic: String { AXID.fixtureTopicTamil }

    func testATopicInProgressHasNoCheatSheetButton() {
        let app = launchHome()

        requireExists(app.element(AXID.fixtureScenarioCard), "the topic card")
        XCTAssertFalse(app.buttons[AXID.cheatSheetButton(topic)].exists, "A topic in progress has no button")
    }

    func testTheListShowsTheLockedLineForATopicInProgress() {
        let app = launchHome()

        openCheatSheetList(app)

        let row = app.element(AXID.cheatSheetListRowLocked(topic))
        requireLabel(of: row, containing: "Finish this topic to see its cheat sheet")
        XCTAssertFalse(app.element(AXID.cheatSheetListRow(topic)).exists, "A locked topic cannot be opened")
        tap(app.buttons[AXID.cheatSheetListClose], "Close on the list")
        requireExists(app.element(AXID.greeting), "Home after Close")
        requireGone(app.element(AXID.cheatSheetList), "the list")
    }

    func testTheListOpensAFinishedTopicsSheetAndClosesBackStepByStep() {
        let app = launchHomeWithUnlockedTopic()

        openCheatSheetList(app)
        let row = app.element(AXID.cheatSheetListRow(topic))
        requireLabel(of: row, containing: "cheat sheet")
        XCTAssertFalse(app.element(AXID.cheatSheetListRowLocked(topic)).exists)

        tap(row, "the finished topic's row")
        requireExists(app.element(AXID.cheatSheetScreen), "the cheat sheet")
        requireLabel(of: app.element(AXID.cheatSheetRow(0)), containing: "zz, zz gloss")

        tap(app.buttons[AXID.cheatSheetClose], "Close on the sheet")
        requireGone(app.element(AXID.cheatSheetScreen), "the sheet")
        requireExists(app.element(AXID.cheatSheetList), "the list again")
        tap(app.buttons[AXID.cheatSheetListClose], "Close on the list")
        requireExists(app.element(AXID.greeting), "Home after Close")
    }

    func testTheSheetLabelsAWordWhoseLessonIsUnreviewed() {
        let app = launchHomeWithUnlockedTopic()

        openCheatSheet(app)

        // One fixture phrase that uses the word is unreviewed, so the word carries the draft label (DECISIONS 048).
        requireExists(app.element(AXID.cheatSheetRowUnreviewed(0)), "the Unreviewed draft label")
    }

    func testResetProgressClearsTheUnlocks() {
        let app = launchHomeWithUnlockedTopic()
        requireExists(app.buttons[AXID.cheatSheetButton(topic)], "the Cheat sheet button")

        goToSettings(app)
        tap(app.element(AXID.settingsReset), "Reset progress")
        requireExists(app.staticTexts["Reset Tamil progress?"], "the confirmation naming Tamil")
        tap(app.sheets.buttons["Reset progress"].firstMatch, "Reset progress in the confirmation")
        requireExists(app.staticTexts["Progress was reset."], "the reset confirmation message")
        app.navigationBars.buttons.firstMatch.tap()

        requireExists(app.element(AXID.greeting), "Home after Reset")
        requireGone(app.buttons[AXID.cheatSheetButton(topic)], "the Cheat sheet button")
        openCheatSheetList(app)
        requireExists(app.element(AXID.cheatSheetListRowLocked(topic)), "the topic locked again")
    }

    func testEachLanguageKeepsItsOwnUnlocks() {
        let app = launchHome(
            language: .tamil,
            extraArguments: [CheatSheetArguments.unlocked(AXID.fixtureTopicTamil, in: .tamil)]
        )
        requireExists(app.buttons[AXID.cheatSheetButton(AXID.fixtureTopicTamil)], "the Tamil topic's button")

        switchLanguage(to: .telugu, in: app)
        requireExists(app.element(AXID.fixtureScenarioCardTelugu), "the Telugu topic card")
        XCTAssertFalse(
            app.buttons[AXID.cheatSheetButton(AXID.fixtureTopicTelugu)].exists,
            "Telugu has not finished its topic"
        )

        switchLanguage(to: .tamil, in: app)
        requireExists(app.buttons[AXID.cheatSheetButton(AXID.fixtureTopicTamil)], "the Tamil topic's button again")
    }
}
