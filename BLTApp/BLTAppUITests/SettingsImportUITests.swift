import XCTest

/// Settings, Lessons section, full tier (DECISIONS 045). The system Files picker is out of process and cannot be
/// driven by XCUITest, so these tests cover what the app itself shows around it. The Import lessons button and its
/// helper text are the Settings happy path in `HappyPathUITests`. Importing and removing are covered by the
/// view-model tests and the import-engine tests in the package.
@MainActor
final class SettingsImportUITests: BLTUITestCase {
    private func openSettings(largestText: Bool = false) -> XCUIApplication {
        let app = launchHome(largestText: largestText)
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")
        return app
    }

    func testNothingImportedShowsNoRemoveButtonAndNoStatus() {
        let app = openSettings()

        requireExists(app.buttons[AXID.settingsImportLessons], "the Import lessons button")
        XCTAssertFalse(app.element(AXID.settingsRemoveImported).exists, "Nothing is imported, so nothing to remove")
        XCTAssertFalse(app.element(AXID.settingsImportStatus).exists, "No import has happened, so no status")
    }
}
