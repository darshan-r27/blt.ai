#if DEBUG
import BLTCatalog
import BLTCore

/// Obviously fake content for previews and UI tests. Every string starts with "zz".
public enum PreviewCatalog {
    static let scenarioID = ScenarioID(rawValue: "zz-scenario")

    public static let catalog = Catalog(scenarios: [scenario], issues: [])

    static let scenario = Scenario(
        id: scenarioID,
        title: "zz scenario",
        subtitle: "zz subtitle",
        romanisationNote: nil,
        items: [respectfulItem, neutralItem],
        language: .tamil
    )

    static let respectfulItem = Item(
        id: ItemID(rawValue: "zz-item-1"),
        scenarioID: scenarioID,
        sourcePrompt: "zz prompt one (to an elder)",
        register: .respectful,
        addressee: .any,
        canonical: "zz canonical one",
        acceptedAnswers: ["zz canonical one", "zz canonical uno", "zz canonical eins"],
        registerVariant: "zz casual one",
        distractors: ["zz wrong one", "zz wrong two"],
        tokens: [Token(word: "zz", english: "zz gloss")],
        note: "zz note",
        reviewStatus: .unreviewed
    )

    static let neutralItem = Item(
        id: ItemID(rawValue: "zz-item-2"),
        scenarioID: scenarioID,
        sourcePrompt: "zz prompt two",
        register: .neutral,
        addressee: .any,
        canonical: "zz canonical two",
        acceptedAnswers: ["zz canonical two", "zz canonical dos", "zz canonical zwei"],
        registerVariant: nil,
        distractors: ["zz wrong three", "zz wrong four", "zz wrong five"],
        tokens: [Token(word: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: .reviewed
    )

    // MARK: Levels

    /// A catalog with levels, for the Home previews and tests (the UI-test fixture above has none).
    /// Level 1 has two lessons, listed out of order on purpose. Level 2 has two lessons. One lesson has no level.
    static let leveledCatalog = Catalog(
        scenarios: [
            lesson("zz-l2-b", title: "zz lesson L2 B", level: Level(number: 2, title: "zz Now", position: 2)),
            lesson("zz-l1-b", title: "zz lesson L1 B", level: Level(number: 1, title: "zz Survival", position: 2)),
            lesson("zz-loose", title: "zz lesson without level", level: nil),
            lesson("zz-l2-a", title: "zz lesson L2 A", level: Level(number: 2, title: "zz Now", position: 1)),
            lesson("zz-l1-a", title: "zz lesson L1 A", level: Level(number: 1, title: "zz Survival", position: 1))
        ],
        issues: []
    )

    /// Four fake items per lesson, ids `<lesson>-i1` to `<lesson>-i4`.
    static func lesson(_ id: String, title: String, level: Level?) -> Scenario {
        let scenarioID = ScenarioID(rawValue: id)
        let items = (1...4).map { number in
            Item(
                id: ItemID(rawValue: "\(id)-i\(number)"),
                scenarioID: scenarioID,
                sourcePrompt: "zz prompt \(id) \(number)",
                register: .neutral,
                addressee: .any,
                canonical: "zz canonical \(id) \(number)",
                acceptedAnswers: ["zz canonical \(id) \(number)", "zz alt a \(id) \(number)", "zz alt b \(id)"],
                registerVariant: nil,
                distractors: ["zz wrong a", "zz wrong b", "zz wrong c"],
                tokens: [Token(word: "zz", english: "zz gloss")],
                note: nil,
                reviewStatus: .unreviewed
            )
        }
        return Scenario(
            id: scenarioID,
            title: title,
            subtitle: "zz subtitle \(id)",
            romanisationNote: nil,
            items: items,
            level: level,
            language: .tamil
        )
    }
}
#endif
