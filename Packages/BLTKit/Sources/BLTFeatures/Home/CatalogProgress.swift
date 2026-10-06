import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

/// Figures derived from the catalog alone, shared by Home, Progress and Settings.
extension Catalog {
    var allItems: [Item] {
        scenarios.flatMap(\.items)
    }

    /// Items that have a register variant: the only ones that can produce a register attempt.
    var variantItemIDs: Set<ItemID> {
        Set(allItems.filter { $0.registerVariant != nil }.map(\.id))
    }

    var totalItemCount: Int {
        allItems.count
    }

    /// Items a native speaker has checked (`reviewStatus == .reviewed`).
    var reviewedItemCount: Int {
        allItems.filter { $0.reviewStatus == .reviewed }.count
    }

    func progressSummary(snapshot: ProgressSnapshot, now: Date) -> ProgressSummary {
        ProgressSummary(snapshot: snapshot, knownItems: allItemIDs, variantItems: variantItemIDs, now: now)
    }
}
