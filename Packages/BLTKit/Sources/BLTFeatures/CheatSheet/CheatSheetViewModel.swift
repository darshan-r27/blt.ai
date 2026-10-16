import BLTCatalog
import BLTDesign
import BLTSession
import Observation

/// Drives one topic's cheat sheet: the topic's title and its words in teaching order. The sheet is built once,
/// from the lesson data, when the model is created. Nothing is stored or read.
@MainActor
@Observable
final class CheatSheetViewModel: Identifiable {
    /// One word of the sheet, ready to show.
    struct Row: Equatable, Identifiable {
        let index: Int
        let entry: CheatSheetEntry
        var id: String { entry.id }
        /// What VoiceOver reads for the word and its meaning: "word, meaning".
        var accessibilityLabel: String { CheatSheetLabels.row(word: entry.word, meaning: entry.meaning) }
        var isUnreviewed: Bool { entry.isUnreviewed }
    }

    let title: String
    let rows: [Row]

    /// The topic's id, so a sheet can be presented as an item.
    let id: String

    init(
        scenario: Scenario,
        buildSheet: @Sendable (Scenario) -> CheatSheet = CheatSheetBuilder.build(from:)
    ) {
        id = scenario.id.rawValue
        title = scenario.title
        rows = buildSheet(scenario).entries.enumerated().map { Row(index: $0.offset, entry: $0.element) }
    }

    var isEmpty: Bool { rows.isEmpty }
}
