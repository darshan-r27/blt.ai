import XCTest

/// Settings, Lessons section. The system Files picker is out of process and cannot be driven by XCUITest,
/// so these tests cover what the app itself shows around it. Importing and removing are covered by the
/// view-model tests and the import-engine tests in the package.
@MainActor
final class SettingsImportUITests: BLTUITestCase {
    private func openSettings(largestText: Bool = false) -> XCUIApplication {
        let app = launchHome(largestText: largestText)
        tap(app.buttons["Settings"], "the Settings button")
        requireExists(app.element(AXID.settingsReset), "Settings")
        return app
    }

    func testSettingsOffersImportLessonsWithItsHelperText() {
        let app = openSettings()

        let importButton = app.buttons[AXID.settingsImportLessons]
        requireExists(importButton, "the Import lessons button")
        XCTAssertEqual(importButton.label, "Import lessons")
        requireExists(
            app.staticTexts["Choose lesson files (.json) from the Files app. Your progress is kept."],
            "the Import lessons helper text"
        )
    }

    func testNothingImportedShowsNoRemoveButtonAndNoStatus() {
        let app = openSettings()

        requireExists(app.buttons[AXID.settingsImportLessons], "the Import lessons button")
        XCTAssertFalse(app.element(AXID.settingsRemoveImported).exists, "Nothing is imported, so nothing to remove")
        XCTAssertFalse(app.element(AXID.settingsImportStatus).exists, "No import has happened, so no status")
    }
}
