import BLTCatalog
import BLTCore
import Foundation
import Testing

/// The three duplicate rules (DECISIONS 038).
struct CatalogDuplicateRuleTests {
    private typealias Fix = CatalogFormatFixtures

    @Test func duplicateSourcePromptDifferingOnlyByCaseSpacingAndPunctuationIsReported() throws {
        let first = Fix.item(id: "zz-1", prompt: "zz Prompt, here")
        let second = Fix.item(id: "zz-2", prompt: " ZZ prompt here? ")
        let catalog = try Fix.load([Fix.scenario(items: [first, second])])
        #expect(catalog.issues.map(\.rule) == [.duplicateSourcePrompt])
        #expect(catalog.issues.first?.itemID == ItemID(rawValue: "zz-2"))
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-1")])
    }

    @Test func duplicateSourcePromptAcrossFilesKeepsTheEarlierFile() throws {
        let first = Fix.scenario(id: "zz-first", items: [Fix.item(id: "zz-1", prompt: "zz same")])
        let second = Fix.scenario(
            id: "zz-second", items: [Fix.item(id: "zz-2", prompt: "ZZ-same"), Fix.item(id: "zz-3")]
        )
        let catalog = try Fix.load([first, second])
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1,
                scenarioID: ScenarioID(rawValue: "zz-second"),
                itemID: ItemID(rawValue: "zz-2"),
                rule: .duplicateSourcePrompt
            )
        ])
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-1"), ItemID(rawValue: "zz-3")])
    }

    @Test func differentSourcePromptsAreAccepted() throws {
        let items = [Fix.item(id: "zz-1", prompt: "zz one"), Fix.item(id: "zz-2", prompt: "zz two")]
        #expect(try Fix.load([Fix.scenario(items: items)]).issues.isEmpty)
    }

    // MARK: Duplicate canonical answers

    @Test func duplicateCanonicalAcrossFilesIsReported() throws {
        let first = Fix.scenario(id: "zz-first", items: [Fix.item(id: "zz-1", canonical: "zz same answer")])
        let second = Fix.scenario(
            id: "zz-second",
            items: [Fix.item(id: "zz-2", canonical: "ZZ same-answer!"), Fix.item(id: "zz-3")]
        )
        let catalog = try Fix.load([first, second])
        #expect(catalog.issues.map(\.rule) == [.duplicateCanonical])
        #expect(catalog.issues.first?.fileIndex == 1)
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-1"), ItemID(rawValue: "zz-3")])
    }

    @Test func repeatedPromptAndCanonicalReportsBothRules() throws {
        let first = Fix.item(id: "zz-1", prompt: "zz p", canonical: "zz a")
        let second = Fix.item(id: "zz-2", prompt: "zz p", canonical: "zz a")
        let catalog = try Fix.load([Fix.scenario(items: [first, second])])
        #expect(Set(catalog.issues.map(\.rule)) == [.duplicateSourcePrompt, .duplicateCanonical])
    }

    @Test func sharedDistractorsAcrossItemsAreAllowed() throws {
        // Both fixtures use the same wrong options ("zz wrong a", "zz wrong b"): they may repeat.
        let items = [Fix.item(id: "zz-1"), Fix.item(id: "zz-2")]
        #expect(try Fix.load([Fix.scenario(items: items)]).issues.isEmpty)
    }

    @Test func aDroppedItemDoesNotClaimItsPromptOrAnswer() throws {
        // The first item is invalid (missing register), so its prompt and answer stay free for the next.
        var broken = Fix.item(id: "zz-1", prompt: "zz p", canonical: "zz a")
        broken.removeValue(forKey: "register")
        let second = Fix.item(id: "zz-2", prompt: "zz p", canonical: "zz a")
        let catalog = try Fix.load([Fix.scenario(items: [broken, second])])
        #expect(catalog.issues.map(\.rule) == [.missingField(.register)])
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-2")])
    }

    // MARK: Duplicate accepted spellings

    @Test func acceptedSpellingsDifferingOnlyByCaseAndEdgeSpacesAreReported() throws {
        let broken = Fix.item(
            id: "zz-1", canonical: "zz a", accepted: ["zz a", "zz b", " ZZ B "]
        )
        let catalog = try Fix.load([Fix.scenario(items: [broken, Fix.item(id: "zz-good")])])
        #expect(catalog.issues.map(\.rule) == [.duplicateAcceptedAnswer])
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
    }

    @Test func acceptedSpellingsDifferingByPunctuationOrInnerSpacingAreAllowed() throws {
        let item = Fix.item(
            id: "zz-1", canonical: "zz a b", accepted: ["zz a b", "zz a b?", "zz a-b", "zz ab", "zz a  b"]
        )
        let catalog = try Fix.load([Fix.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-1")])
    }

    @Test func sameAcceptedSpellingInTwoDifferentItemsIsAllowed() throws {
        let first = Fix.item(id: "zz-1", accepted: ["zz canonical zz-1", "zz shared", "zz c1"])
        let second = Fix.item(id: "zz-2", accepted: ["zz canonical zz-2", "zz shared", "zz c2"])
        #expect(try Fix.load([Fix.scenario(items: [first, second])]).issues.isEmpty)
    }
}
