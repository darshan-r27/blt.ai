import BLTCatalog
import BLTProgress
import Foundation

/// Chooses which items a session contains, and in what order.
///
/// Selection is prioritised so learning is not harmed; only the choice among equals and the final
/// order are random, so a learner cannot get by on remembering "question 3 is always the greeting".
/// Pure given a generator: the same inputs and the same seeded generator give the same plan.
public struct SessionPlanner: Sendable {
    public init() {}

    /// Selects at most `limit` items, then shuffles them.
    ///
    /// 1. Due items come first, earliest due first (wrong answers are due immediately, so they
    ///    always beat anything new). If there are more due items than `limit`, the earliest win.
    /// 2. Remaining places are filled with a random sample of the unseen items.
    /// 3. Seen items that are not yet due are never included; "Review anyway" is a separate action.
    ///
    /// The selected set is then shuffled, so due and new items interleave.
    public func plan(
        scenario: Scenario,
        snapshot: ProgressSnapshot,
        now: Date,
        limit: Int = 10,
        using rng: inout some RandomNumberGenerator
    ) -> [Item] {
        let cap = max(0, limit)
        let due = seen(in: scenario, snapshot: snapshot)
            .filter { $0.review.isDue(at: now) }
            .prefix(cap)
            .map { scenario.items[$0.index] }
        let unseen = scenario.items.filter { snapshot.reviews[$0.id] == nil }
        let sampled = unseen.shuffled(using: &rng).prefix(cap - due.count)
        return (due + sampled).shuffled(using: &rng)
    }

    /// The `limit` items with the earliest `due` among items that already have a `ReviewState`,
    /// in random order. Unseen items are excluded. Used when `plan` is empty ("Review anyway").
    public func reviewAnywayPlan(
        scenario: Scenario,
        snapshot: ProgressSnapshot,
        limit: Int = 10,
        using rng: inout some RandomNumberGenerator
    ) -> [Item] {
        let earliest = seen(in: scenario, snapshot: snapshot)
            .prefix(max(0, limit))
            .map { scenario.items[$0.index] }
        return earliest.shuffled(using: &rng)
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
