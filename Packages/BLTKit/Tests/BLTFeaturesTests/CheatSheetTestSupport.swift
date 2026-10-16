import BLTCatalog
import BLTCore

/// Fake `zz` lessons for the cheat sheet screen tests.
enum CheatSheetFixtures {
    static func item(_ number: Int, scenario: ScenarioID, words: [String], status: ReviewStatus) -> Item {
        Item(
            id: ItemID(rawValue: "zz-item-\(number)"),
            scenarioID: scenario,
            sourcePrompt: "zz prompt \(number)",
            register: .neutral,
            addressee: .any,
            canonical: "zz example \(number)",
            acceptedAnswers: ["zz example \(number)"],
            registerVariant: nil,
            distractors: ["zz wrong"],
            tokens: words.map { Token(word: $0, english: "\($0) gloss") },
            note: nil,
            reviewStatus: status
        )
    }

    static func scenario(_ name: String, items: [[String]] = [], status: ReviewStatus = .reviewed) -> Scenario {
        let id = ScenarioID(rawValue: "zz-\(name)")
        return Scenario(
            id: id,
            title: "zz title \(name)",
            subtitle: "zz subtitle",
            romanisationNote: nil,
            items: items.enumerated().map { Self.item($0.offset + 1, scenario: id, words: $0.element, status: status) },
            language: .tamil
        )
    }
}
