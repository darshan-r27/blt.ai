import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

/// Per-scenario figures shown on a Home card. Built from the catalog and a progress snapshot only;
/// progress for items no longer in the catalog is ignored.
///
/// An item is **complete** only when its latest outcome is `.correct`. Never answered, answered in
/// the other register (`.wrongRegister`) and answered wrongly (`.wrong`) all count as incomplete, so
/// a wrong answer keeps the scenario below 100% (DECISIONS 033).
public struct ScenarioSummary: Sendable, Equatable, Identifiable {
    public let id: ScenarioID
    public let title: String
    public let subtitle: String
    public let totalCount: Int
    /// Items whose latest outcome is `.correct`.
    public let completedCount: Int

    public init(scenario: Scenario, snapshot: ProgressSnapshot) {
        id = scenario.id
        title = scenario.title
        subtitle = scenario.subtitle
        totalCount = scenario.items.count
        completedCount = scenario.items.filter { snapshot.reviews[$0.id]?.lastOutcome == .correct }.count
    }

    /// Completed over total; 0 when the scenario has no items.
    public var completionFraction: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    /// Whole-number percent, rounded down so 100 means every item is complete.
    public var completionPercent: Int {
        totalCount == 0 ? 0 : completedCount * 100 / totalCount
    }
}
