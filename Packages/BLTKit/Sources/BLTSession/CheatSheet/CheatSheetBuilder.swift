import BLTCatalog
import BLTCore

/// Builds a topic's cheat sheet from its lesson data. A pure function: nothing is stored or read.
public enum CheatSheetBuilder {
    private struct Draft {
        let word: String
        var meanings: [String]
        let example: String
        var isUnreviewed: Bool
    }

    public static func build(from scenario: Scenario) -> CheatSheet {
        var order: [String] = []
        var drafts: [String: Draft] = [:]
        for item in scenario.items {
            let unreviewed = item.reviewStatus == .unreviewed
            for token in item.tokens {
                let word = token.word.trimmingSpaces
                guard !word.isEmpty else { continue }
                let key = word.lowercased()
                let meaning = token.english.trimmingSpaces
                if var draft = drafts[key] {
                    if !meaning.isEmpty, !draft.meanings.contains(where: { $0.lowercased() == meaning.lowercased() }) {
                        draft.meanings.append(meaning)
                    }
                    draft.isUnreviewed = draft.isUnreviewed || unreviewed
                    drafts[key] = draft
                } else {
                    order.append(key)
                    drafts[key] = Draft(
                        word: word,
                        meanings: meaning.isEmpty ? [] : [meaning],
                        example: item.canonical,
                        isUnreviewed: unreviewed
                    )
                }
            }
        }
        let entries = order.compactMap { key in
            drafts[key].map { draft in
                CheatSheetEntry(
                    id: key,
                    word: draft.word,
                    meaning: draft.meanings.joined(separator: "; "),
                    example: draft.example,
                    isUnreviewed: draft.isUnreviewed
                )
            }
        }
        return CheatSheet(scenarioID: scenario.id, entries: entries)
    }
}

private extension String {
    var trimmingSpaces: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
