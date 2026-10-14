import XCTest

/// `performAccessibilityAudit()` on the daily-practice screens at the default text size (DECISIONS 047): Home with
/// a streak, the end-of-session summary, the streak screen, and the Settings section. Full tier: the PR tier's
/// audits (`AccessibilityUITests`) stay as they were, and these screens' happy paths are in `HappyPathUITests`.
/// The same four at the largest size are in `AccessibilityLargeTextUITests`. The machinery and the narrow,
/// documented exceptions are in `AccessibilityAuditCase`; nothing is added to them for these screens.
@MainActor
final class AccessibilityPracticeUITests: AccessibilityAuditCase {
    func testHomeWithStreakAudit() throws { try audit(.homeWithStreak, largestText: false) }
    func testSessionSummaryAudit() throws { try audit(.sessionSummary, largestText: false) }
    func testStreakScreenAudit() throws { try audit(.streakScreen, largestText: false) }
    func testSettingsDailyPracticeAudit() throws { try audit(.settingsDailyPractice, largestText: false) }
}
