import XCTest

/// Launch arguments that seed cheat sheet unlocks (UITestLaunch.swift lists them). They mark topics complete in the
/// unlock record, so a test sees the "Cheat sheet" button without answering a question.
enum CheatSheetArguments {
    /// Marks a topic complete in both courses (an id a course does not have is ignored by its screens).
    static func unlocked(_ topicID: String) -> String {
        "--uitest-cheatsheets=\(topicID)"
    }

    /// Marks a topic complete in one course only.
    static func unlocked(_ topicID: String, in language: UITestLanguage) -> String {
        "--uitest-cheatsheets-\(language.rawValue)=\(topicID)"
    }
}

/// Accessibility identifiers of the cheat sheet screens, copied as literals like the rest of `AXID` (source of
/// truth: Packages/BLTKit/Sources/BLTDesign/AccessibilityID.swift).
extension AXID {
    static let homeCheatSheets = "home.cheatSheets"
    static let cheatSheetList = "cheatSheet.list"
    static let cheatSheetScreen = "cheatSheet.screen"
    static let cheatSheetListClose = "cheatSheet.list.close"
    static let cheatSheetClose = "cheatSheet.close"
    /// The fixture's topic ids (PreviewCatalog): the only topic of each course.
    static let fixtureTopicTamil = "zz-scenario"
    static let fixtureTopicTelugu = "zz-scenario-telugu"

    static func cheatSheetButton(_ topicID: String) -> String { "cheatSheet.button.\(topicID)" }
    static func cheatSheetListRow(_ topicID: String) -> String { "cheatSheet.list.row.\(topicID)" }
    static func cheatSheetListRowLocked(_ topicID: String) -> String { "cheatSheet.list.row.locked.\(topicID)" }
    static func cheatSheetRow(_ index: Int) -> String { "cheatSheet.row.\(index)" }
    static func cheatSheetRowUnreviewed(_ index: Int) -> String { "cheatSheet.row.unreviewed.\(index)" }

    static func fixtureTopic(_ language: UITestLanguage) -> String {
        language == .tamil ? fixtureTopicTamil : fixtureTopicTelugu
    }
}

extension BLTUITestCase {
    /// Home with the fixture topic marked complete in both courses.
    func launchHomeWithUnlockedTopic(
        language: UITestLanguage = .tamil,
        largestText: Bool = false
    ) -> XCUIApplication {
        launchHome(
            language: language,
            largestText: largestText,
            extraArguments: [CheatSheetArguments.unlocked(AXID.fixtureTopic(language))]
        )
    }

    /// The Cheat sheets row on Home, then the list screen.
    func openCheatSheetList(_ app: XCUIApplication) {
        scrollIntoView(app.element(AXID.homeCheatSheets), in: app)
        tap(app.element(AXID.homeCheatSheets), "the Cheat sheets row")
        requireExists(app.element(AXID.cheatSheetList), "the Cheat sheets list")
    }

    /// The "Cheat sheet" button on the fixture topic's card, then the sheet.
    func openCheatSheet(_ app: XCUIApplication, language: UITestLanguage = .tamil) {
        let button = app.buttons[AXID.cheatSheetButton(AXID.fixtureTopic(language))]
        scrollIntoView(button, in: app)
        tap(button, "the Cheat sheet button")
        requireExists(app.element(AXID.cheatSheetScreen), "the cheat sheet")
    }
}
