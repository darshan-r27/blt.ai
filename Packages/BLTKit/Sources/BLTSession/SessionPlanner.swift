import BLTCatalog
import BLTProgress
import Foundation

/// Chooses which items a session contains. Pure: the same inputs always give the same plan.
public struct SessionPlanner: Sendable {
    public init() {}

    /// Due items first (earliest due first, content order breaks ties), then unseen items in content order.
    /// Items with a `ReviewState` that is not yet due are excluded. Capped at `limit`.
    public func plan(scenario: Scenario, snapshot: ProgressSnapshot, now: Date, limit: Int = 10) -> [Item] {
        let due = seen(in: scenario, snapshot: snapshot).filter { $0.review.isDue(at: now) }
        let unseen = scenario.items.filter { snapshot.reviews[$0.id] == nil }
        let ordered = due.map { scenario.items[$0.index] } + unseen
        return Array(ordered.prefix(max(0, limit)))
    }

    /// The `limit` items with the earliest `due` among items that already have a `ReviewState`.
    /// Unseen items are excluded. Used when `plan` is empty ("Review anyway").
    public func reviewAnywayPlan(scenario: Scenario, snapshot: ProgressSnapshot, limit: Int = 10) -> [Item] {
        let ordered = seen(in: scenario, snapshot: snapshot).map { scenario.items[$0.index] }
        return Array(ordered.prefix(max(0, limit)))
    }

    /// Items that have a `ReviewState`, as content indices, sorted by `due` with content order breaking ties.
    private func seen(in scenario: Scenario, snapshot: ProgressSnapshot) -> [(index: Int, review: ReviewState)] {
        var found: [(index: Int, review: ReviewState)] = []
        for (index, item) in scenario.items.enumerated() {
            if let review = snapshot.reviews[item.id] {
                found.append((index, review))
            }
        }
        return found.sorted { lhs, rhs in
            lhs.review.due == rhs.review.due ? lhs.index < rhs.index : lhs.review.due < rhs.review.due
        }
    }
}
