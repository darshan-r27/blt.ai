import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

/// Per-scenario figures shown on a Home card. Built from the catalog and a progress snapshot only;
/// progress for items no longer in the catalog is ignored.
public struct ScenarioSummary: Sendable, Equatable, Identifiable {
    public let id: ScenarioID
    public let title: String
    public let subtitle: String
    /// Items that have been attempted and whose review date has arrived (`due <= now`).
    public let dueCount: Int
    /// Items never attempted.
    public let newCount: Int
    public let learnedCount: Int
    public let totalCount: Int
    /// Items answered at least once: the "n of N answered" figure (DECISIONS 031).
    public let answeredCount: Int

    public init(scenario: Scenario, snapshot: ProgressSnapshot, now: Date) {
        id = scenario.id
        title = scenario.title
        subtitle = scenario.subtitle
        let reviews = scenario.items.compactMap { snapshot.reviews[$0.id] }
        dueCount = reviews.filter { $0.isDue(at: now) }.count
        newCount = scenario.items.count - reviews.count
        learnedCount = reviews.filter(\.isLearned).count
        totalCount = scenario.items.count
        answeredCount = reviews.count
    }
}
