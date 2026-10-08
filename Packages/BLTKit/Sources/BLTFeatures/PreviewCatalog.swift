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
        items: [respectfulItem, neutralItem]
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
        tokens: [Token(tamil: "zz", english: "zz gloss")],
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
        tokens: [Token(tamil: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: .reviewed
    )
}
#endif
