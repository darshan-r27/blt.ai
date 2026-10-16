import BLTCatalog
import BLTCore
import BLTSession
import Testing

struct CheatSheetBuilderTests {
    private func item(
        _ number: Int,
        canonical: String,
        tokens: [(String, String)],
        status: ReviewStatus = .reviewed
    ) -> Item {
        Item(
            id: ItemID(rawValue: "zz-\(number)"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz prompt \(number)",
            register: .neutral,
            addressee: .any,
            canonical: canonical,
            acceptedAnswers: [canonical, "zz b \(number)", "zz c \(number)"],
            registerVariant: nil,
            distractors: ["zz w1", "zz w2", "zz w3"],
            tokens: tokens.map { Token(word: $0.0, english: $0.1) },
            note: nil,
            reviewStatus: status
        )
    }

    private func scenario(_ items: [Item]) -> Scenario {
        Scenario(
            id: ScenarioID(rawValue: "zz-s"),
            title: "zz title",
            subtitle: "zz subtitle",
            romanisationNote: nil,
            items: items,
            language: .tamil
        )
    }

    @Test func emptyScenarioGivesAnEmptySheet() {
        let sheet = CheatSheetBuilder.build(from: scenario([]))
        #expect(sheet.entries.isEmpty)
        #expect(sheet.scenarioID == ScenarioID(rawValue: "zz-s"))
    }

    @Test func repeatedWordAppearsOnceWithTheFirstExample() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz aa bb", tokens: [("aa", "one"), ("bb", "two")]),
            item(2, canonical: "zz aa cc", tokens: [("aa", "one"), ("cc", "three")])
        ]))
        #expect(sheet.entries.map(\.word) == ["aa", "bb", "cc"])
        #expect(sheet.entries[0].example == "zz aa bb")
        #expect(sheet.entries[0].meaning == "one")
    }

    @Test func oneWordWithTwoMeaningsJoinsThem() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz aa", tokens: [("aa", "you (respectful)")]),
            item(2, canonical: "zz aa bb", tokens: [("aa", "you (casual)"), ("bb", "go")]),
            item(3, canonical: "zz aa", tokens: [("aa", "You (Casual)")])
        ]))
        #expect(sheet.entries.count == 2)
        #expect(sheet.entries[0].meaning == "you (respectful); you (casual)")
        #expect(sheet.entries[1].meaning == "go")
    }

    @Test func mixedReviewStatusFlagsAWordIfAnyPhraseIsUnreviewed() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz aa bb", tokens: [("aa", "one"), ("bb", "two")], status: .reviewed),
            item(2, canonical: "zz aa", tokens: [("aa", "one")], status: .unreviewed)
        ]))
        let flags = Dictionary(uniqueKeysWithValues: sheet.entries.map { ($0.word, $0.isUnreviewed) })
        #expect(flags == ["aa": true, "bb": false])
    }

    @Test func allReviewedPhrasesGiveNoFlag() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz aa", tokens: [("aa", "one")]),
            item(2, canonical: "zz aa", tokens: [("aa", "one")])
        ]))
        #expect(sheet.entries.map(\.isUnreviewed) == [false])
    }

    @Test func caseInsensitiveDuplicatesAreMerged() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "Zz Aa", tokens: [("Aa", "one")]),
            item(2, canonical: "zz aa", tokens: [("aa", "one")])
        ]))
        #expect(sheet.entries.count == 1)
        #expect(sheet.entries[0].word == "Aa")
        #expect(sheet.entries[0].id == "aa")
        #expect(sheet.entries[0].example == "Zz Aa")
    }

    @Test func teachingOrderIsKept() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz dd aa", tokens: [("dd", "four"), ("aa", "one")]),
            item(2, canonical: "zz cc bb aa", tokens: [("cc", "three"), ("bb", "two"), ("aa", "one")])
        ]))
        #expect(sheet.entries.map(\.word) == ["dd", "aa", "cc", "bb"])
    }

    @Test func blankWordsAreSkipped() {
        let sheet = CheatSheetBuilder.build(from: scenario([
            item(1, canonical: "zz aa", tokens: [("  ", "nothing"), (" aa ", "one")])
        ]))
        #expect(sheet.entries.map(\.word) == ["aa"])
    }
}
