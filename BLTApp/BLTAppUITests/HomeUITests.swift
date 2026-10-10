import XCTest

/// Home, full tier (DECISIONS 045): what a scenario card shows. The layout happy path is in `HappyPathUITests`.
/// The completion rules (an item counts as complete only when its latest recorded outcome is correct) are checked
/// in the package, in `SessionCompletionFlowTests` and `HomeViewModelTests`.
@MainActor
final class HomeUITests: BLTUITestCase {
    func testCardShowsOnlyCompletionNotTheOldCounts() {
        let app = launchHome()

        requireCompletion(percent: 0, in: app)
        let card = app.element(AXID.fixtureScenarioCard)
        XCTAssertEqual(card.label, "zz scenario, zz subtitle, 0 percent complete")
        let oldLines = NSPredicate(
            format: "label CONTAINS ' due' OR label CONTAINS ' new' OR label CONTAINS 'answered'"
        )
        XCTAssertEqual(app.staticTexts.matching(oldLines).count, 0, "The old count lines must be gone")
        XCTAssertFalse(app.staticTexts["Nothing is due for review right now."].exists)
    }
}
