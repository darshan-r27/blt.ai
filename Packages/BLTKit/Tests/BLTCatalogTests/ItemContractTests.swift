import BLTCatalog
import BLTCore
import Foundation
import Testing

struct ItemContractTests {
    @Test func minimalFixtureMatchesTheContentSchemaKeys() throws {
        let url = try #require(
            Bundle.module.url(forResource: "valid-minimal", withExtension: "json", subdirectory: "Fixtures")
        )
        let data = try Data(contentsOf: url)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])
        let item = try #require(items.first)
        let expected: Set = [
            "id", "sourcePrompt", "register", "addressee", "canonical", "acceptedAnswers",
            "registerVariant", "distractors", "tokens", "note", "reviewStatus"
        ]
        #expect(Set(item.keys) == expected)
    }

    @Test func catalogLooksUpItemsAndListsIDs() {
        let id = ItemID(rawValue: "zz-1")
        let item = Item(
            id: id, scenarioID: ScenarioID(rawValue: "zz-s"), sourcePrompt: "zz", register: .neutral,
            addressee: .any, canonical: "zz a", acceptedAnswers: ["zz a", "zz b", "zz c"], registerVariant: nil,
            distractors: ["zz d", "zz e", "zz f"], tokens: [], note: nil, reviewStatus: .unreviewed
        )
        let scenario = Scenario(
            id: ScenarioID(rawValue: "zz-s"), title: "zz", subtitle: "zz", romanisationNote: nil, items: [item]
        )
        let catalog = Catalog(scenarios: [scenario], issues: [])
        #expect(catalog.item(id) == item)
        #expect(catalog.item(ItemID(rawValue: "zz-missing")) == nil)
        #expect(catalog.allItemIDs == [id])
    }
}
