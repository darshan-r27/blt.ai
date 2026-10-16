import BLTCatalog
import BLTCore
import BLTDesign
import BLTSession
import Testing

@testable import BLTFeatures

@MainActor
struct CheatSheetViewModelTests {
    @Test func rowsFollowTheTeachingOrder() {
        let model = CheatSheetViewModel(scenario: CheatSheetFixtures.scenario("a", items: [["zz b", "zz a"], ["zz c"]]))
        #expect(model.title == "zz title a")
        #expect(model.rows.map(\.entry.word) == ["zz b", "zz a", "zz c"])
        #expect(model.rows.map(\.index) == [0, 1, 2])
        #expect(model.isEmpty == false)
    }

    @Test func eachRowShowsMeaningAndExample() throws {
        let model = CheatSheetViewModel(scenario: CheatSheetFixtures.scenario("a", items: [["zz b"], ["zz b", "zz c"]]))
        let first = try #require(model.rows.first)
        #expect(first.entry.meaning == "zz b gloss")
        #expect(first.entry.example == "zz example 1")
        #expect(first.accessibilityLabel == CheatSheetLabels.row(word: "zz b", meaning: "zz b gloss"))
        #expect(model.rows.count == 2)
    }

    @Test func unreviewedWordsAreFlagged() {
        let unreviewed = CheatSheetFixtures.scenario("a", items: [["zz b"]], status: .unreviewed)
        let draft = CheatSheetViewModel(scenario: unreviewed)
        #expect(draft.rows.map(\.isUnreviewed) == [true])
        let reviewed = CheatSheetFixtures.scenario("a", items: [["zz b"]], status: .reviewed)
        let checked = CheatSheetViewModel(scenario: reviewed)
        #expect(checked.rows.map(\.isUnreviewed) == [false])
    }

    @Test func aTopicWithNoWordsIsEmpty() {
        let model = CheatSheetViewModel(scenario: CheatSheetFixtures.scenario("empty"))
        #expect(model.isEmpty)
        #expect(model.rows.isEmpty)
    }

    @Test func theSheetIsBuiltByTheInjectedBuilder() {
        let entry = CheatSheetEntry(id: "zz x", word: "zz x", meaning: "zz m", example: "zz e", isUnreviewed: false)
        let scenario = CheatSheetFixtures.scenario("a", items: [["zz b"]])
        let model = CheatSheetViewModel(scenario: scenario) { CheatSheet(scenarioID: $0.id, entries: [entry]) }
        #expect(model.rows.map(\.entry) == [entry])
    }
}
