import XCTest

/// `performAccessibilityAudit()` on the cheat sheet screens (DECISIONS 048), at the default text size and at the
/// largest accessibility size: a sheet, the list with a finished topic, and the list with a topic still locked.
/// Full tier, like `AccessibilityPracticeUITests`. The machinery and the narrow, documented exceptions are in
/// `AccessibilityAuditCase`; nothing is added to them for these screens.
@MainActor
final class AccessibilityCheatSheetUITests: AccessibilityAuditCase {
    func testCheatSheetAudit() throws { try audit(.cheatSheet, largestText: false) }
    func testCheatSheetListAudit() throws { try audit(.cheatSheetList, largestText: false) }
    func testCheatSheetListLockedAudit() throws { try audit(.cheatSheetListLocked, largestText: false) }

    func testCheatSheetAuditAtXXXL() throws { try audit(.cheatSheet, largestText: true) }
    func testCheatSheetListAuditAtXXXL() throws { try audit(.cheatSheetList, largestText: true) }
    func testCheatSheetListLockedAuditAtXXXL() throws { try audit(.cheatSheetListLocked, largestText: true) }

    func testCheatSheetControlsAreReachableAtXXXL() {
        let app = open(.cheatSheet, largestText: true)
        XCTAssertTrue(app.buttons[AXID.cheatSheetClose].isHittable, "Close on the sheet")
        scrollIntoView(app.element(AXID.cheatSheetRow(0)), in: app)
        XCTAssertTrue(app.element(AXID.cheatSheetRow(0)).isHittable, "The first word")
    }

    func testCheatSheetListControlsAreReachableAtXXXL() {
        let app = open(.cheatSheetList, largestText: true)
        XCTAssertTrue(app.buttons[AXID.cheatSheetListClose].isHittable, "Close on the list")
        scrollIntoView(app.element(AXID.cheatSheetListRow(AXID.fixtureTopicTamil)), in: app)
        XCTAssertTrue(app.element(AXID.cheatSheetListRow(AXID.fixtureTopicTamil)).isHittable, "The topic's row")
    }
}
