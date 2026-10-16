import BLTCatalog
import BLTCore
import BLTDesign
import Testing

@testable import BLTFeatures

@MainActor
struct CheatSheetListViewModelTests {
    private let one = CheatSheetFixtures.scenario("one", items: [["zz b"]])
    private let two = CheatSheetFixtures.scenario("two", items: [["zz c"]])
    private let three = CheatSheetFixtures.scenario("three")

    @Test func rowsKeepCatalogOrder() {
        let model = CheatSheetListViewModel(scenarios: [two, one, three])
        #expect(model.rows.map(\.title) == ["zz title two", "zz title one", "zz title three"])
        #expect(model.isEmpty == false)
    }

    @Test func onlyUnlockedTopicsAreUnlocked() {
        let model = CheatSheetListViewModel(scenarios: [one, two, three], unlockedTopicIDs: [one.id, three.id])
        #expect(model.rows.map(\.isUnlocked) == [true, false, true])
    }

    @Test func labelsMatchTheLockState() throws {
        let model = CheatSheetListViewModel(scenarios: [one, two], unlockedTopicIDs: [one.id])
        let unlocked = try #require(model.rows.first)
        let locked = try #require(model.rows.last)
        #expect(unlocked.accessibilityLabel == CheatSheetLabels.listRowUnlocked(topic: "zz title one"))
        #expect(locked.accessibilityLabel == CheatSheetLabels.listRowLocked(topic: "zz title two"))
    }

    @Test func anUnlockedTopicOpensItsSheet() throws {
        let model = CheatSheetListViewModel(scenarios: [one, two], unlockedTopicIDs: [one.id])
        let sheet = try #require(model.sheetModel(for: one.id))
        #expect(sheet.title == "zz title one")
        #expect(sheet.rows.map(\.entry.word) == ["zz b"])
    }

    @Test func aLockedOrUnknownTopicHasNoSheet() {
        let gone = ScenarioID(rawValue: "zz-gone")
        let model = CheatSheetListViewModel(scenarios: [one, two], unlockedTopicIDs: [one.id, gone])
        #expect(model.sheetModel(for: two.id) == nil)
        #expect(model.sheetModel(for: gone) == nil)
    }

    @Test func unlockedIdsOfOtherLanguagesAddNoRows() {
        let model = CheatSheetListViewModel(scenarios: [one], unlockedTopicIDs: [ScenarioID(rawValue: "zz-other")])
        #expect(model.rows.count == 1)
        #expect(model.rows.first?.isUnlocked == false)
    }

    @Test func noTopicsGivesAnEmptyList() {
        let model = CheatSheetListViewModel()
        #expect(model.isEmpty)
        #expect(model.rows.isEmpty)
    }

    @Test func anUnlockedTopicWithNoWordsOpensAnEmptySheet() throws {
        let model = CheatSheetListViewModel(scenarios: [three], unlockedTopicIDs: [three.id])
        let sheet = try #require(model.sheetModel(for: three.id))
        #expect(sheet.isEmpty)
    }
}
