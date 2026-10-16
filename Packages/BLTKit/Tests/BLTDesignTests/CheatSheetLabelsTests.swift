import BLTDesign
import Testing

struct CheatSheetLabelsTests {
    @Test func fixedStringsAreExact() {
        #expect(CheatSheetLabels.cardButtonTitle == "Cheat sheet")
        #expect(CheatSheetLabels.homeEntryTitle == "Cheat sheets")
        #expect(CheatSheetLabels.screenTitle == "Cheat sheets")
        #expect(CheatSheetLabels.lockedLine == "Finish this topic to see its cheat sheet")
        #expect(CheatSheetLabels.unreviewed == "Unreviewed draft")
    }

    @Test func rowReadsWordThenMeaning() {
        #expect(CheatSheetLabels.row(word: "zz-one", meaning: "to go") == "zz-one, to go")
        #expect(CheatSheetLabels.row(word: "  zz-one ", meaning: " to go\n") == "zz-one, to go")
    }

    @Test func rowWithAMissingPartReadsTheOtherAlone() {
        #expect(CheatSheetLabels.row(word: "zz-one", meaning: "") == "zz-one")
        #expect(CheatSheetLabels.row(word: " ", meaning: "to go") == "to go")
        #expect(CheatSheetLabels.row(word: "", meaning: "").isEmpty)
    }

    @Test func listRowLabelsNameTheTopicAndItsState() {
        #expect(CheatSheetLabels.listRowUnlocked(topic: "Getting around") == "Getting around, cheat sheet")
        #expect(
            CheatSheetLabels.listRowLocked(topic: "Getting around")
                == "Getting around, locked. Finish this topic to see its cheat sheet"
        )
    }

    @Test func wordingIsCalm() {
        let all = [
            CheatSheetLabels.cardButtonTitle, CheatSheetLabels.lockedLine, CheatSheetLabels.unreviewed,
            CheatSheetLabels.listRowLocked(topic: "zz")
        ].joined(separator: " ").lowercased()
        for word in ["error", "warning", "failed", "wrong", "!"] {
            #expect(!all.contains(word))
        }
    }
}
