import XCTest

/// PR tier (DECISIONS 045): `performAccessibilityAudit()` on every screen at the default text size. The same
/// screens at the largest accessibility size are in `AccessibilityLargeTextUITests`, which runs in the full tier.
/// The machinery and the narrow, documented exceptions are in `AccessibilityAuditCase`.
@MainActor
final class AccessibilityUITests: AccessibilityAuditCase {
    func testIntroAudit() throws { try audit(.intro, largestText: false) }
    func testNameEntryAudit() throws { try audit(.nameEntry, largestText: false) }
    func testHomeAudit() throws { try audit(.home, largestText: false) }
    func testQuestionAudit() throws { try audit(.question, largestText: false) }
    func testFeedbackAudit() throws { try audit(.feedback, largestText: false) }
    func testProgressAudit() throws { try audit(.progress, largestText: false) }
    func testSettingsAudit() throws { try audit(.settings, largestText: false) }
    func testChangeNameSheetAudit() throws { try audit(.changeName, largestText: false) }
}
