import BLTCatalog
import BLTCore
import BLTDesign
import BLTSession
import Observation

/// Drives the list of every topic of the course being learned, in catalog order. A topic whose id is in the
/// unlocked set opens its sheet; any other topic shows a calm locked line and cannot be opened.
@MainActor
@Observable
final class CheatSheetListViewModel {
    struct Row: Equatable, Identifiable {
        let id: ScenarioID
        let title: String
        let isUnlocked: Bool

        var accessibilityLabel: String {
            isUnlocked
                ? CheatSheetLabels.listRowUnlocked(topic: title)
                : CheatSheetLabels.listRowLocked(topic: title)
        }
    }

    let rows: [Row]

    private let scenarios: [ScenarioID: Scenario]
    private let buildSheet: @Sendable (Scenario) -> CheatSheet

    init(
        scenarios: [Scenario] = [],
        unlockedTopicIDs: Set<ScenarioID> = [],
        buildSheet: @escaping @Sendable (Scenario) -> CheatSheet = CheatSheetBuilder.build(from:)
    ) {
        rows = scenarios.map { Row(id: $0.id, title: $0.title, isUnlocked: unlockedTopicIDs.contains($0.id)) }
        self.scenarios = Dictionary(scenarios.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.buildSheet = buildSheet
    }

    var isEmpty: Bool { rows.isEmpty }

    /// The sheet for an unlocked topic, or `nil` when the topic is locked or unknown.
    func sheetModel(for id: ScenarioID) -> CheatSheetViewModel? {
        guard rows.first(where: { $0.id == id })?.isUnlocked == true, let scenario = scenarios[id] else {
            return nil
        }
        return CheatSheetViewModel(scenario: scenario, buildSheet: buildSheet)
    }
}
