import BLTCatalog
import BLTCore
import Foundation
import Testing

/// The optional item-level `script` field (DECISIONS 040, 044): the canonical answer in the lesson
/// language's own script. Fixtures are one letter repeated, written as escapes, never a real word.
struct CatalogScriptTests {
    private typealias Fix = CatalogFormatFixtures

    private func loaded(
        script: Any?,
        language: String = "tamil",
        extraKeys: [String: Any] = [:]
    ) throws -> Catalog {
        var item = Fix.item(id: "zz-1")
        if let script { item["script"] = script }
        item.merge(extraKeys) { _, new in new }
        return try Fix.load([Fix.scenario(language: language, items: [item, Fix.item(id: "zz-good")])])
    }

    @Test func missingScriptIsValid() throws {
        let catalog = try loaded(script: nil)
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-1"))?.script == nil)
    }

    @Test func validScriptIsKeptInBothLanguages() throws {
        let tamil = try loaded(script: Fix.fakeTamil)
        #expect(tamil.issues.isEmpty)
        #expect(tamil.item(ItemID(rawValue: "zz-1"))?.script == Fix.fakeTamil)

        let telugu = try loaded(script: Fix.fakeTelugu, language: "telugu")
        #expect(telugu.issues.isEmpty)
        #expect(telugu.item(ItemID(rawValue: "zz-1"))?.script == Fix.fakeTelugu)
    }

    @Test func scriptMustBeInTheLessonsOwnLanguage() throws {
        let teluguInTamil = try loaded(script: Fix.fakeTelugu, language: "tamil")
        #expect(teluguInTamil.issues.map(\.rule) == [.scriptMissingNativeLetters])
        #expect(teluguInTamil.allItemIDs == [ItemID(rawValue: "zz-good")])

        let tamilInTelugu = try loaded(script: Fix.fakeTamil, language: "telugu")
        #expect(tamilInTelugu.issues.map(\.rule) == [.scriptMissingNativeLetters])
        #expect(tamilInTelugu.allItemIDs == [ItemID(rawValue: "zz-good")])
    }

    @Test func nativeScriptIsStillBannedInEveryOtherField() throws {
        for language in ["tamil", "telugu"] {
            for letters in [Fix.fakeTamil, Fix.fakeTelugu] {
                var item = Fix.item(id: "zz-2")
                item["note"] = letters
                let catalog = try Fix.load([Fix.scenario(language: language, items: [item, Fix.item(id: "zz-good")])])
                #expect(catalog.issues.map(\.rule) == [.tamilScriptInField(.note)])
                #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
            }
        }
    }

    @Test func teluguScriptIsRejectedInEveryOtherKindOfField() throws {
        let telugu = "zz\u{0C05}"
        let edits: [(ContentIssue.Field, (inout [String: Any]) -> Void)] = [
            (.sourcePrompt, { $0["sourcePrompt"] = telugu }),
            (.canonical, { $0["canonical"] = telugu }),
            (.note, { $0["note"] = telugu }),
            (.distractors, { $0["distractors"] = [telugu, "zz wrong b"] }),
            (.registerVariant, { $0["registerVariant"] = telugu }),
            (.tokens, { $0["tokens"] = [["word": "zz", "english": telugu]] })
        ]
        for (field, edit) in edits {
            var item = Fix.item(id: "zz-2")
            edit(&item)
            let catalog = try Fix.load([Fix.scenario(language: "telugu", items: [item, Fix.item(id: "zz-good")])])
            #expect(catalog.issues.map(\.rule) == [.tamilScriptInField(field)])
            #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
        }
        for scalar in ["\u{0C00}", "\u{0C7F}"] {
            var item = Fix.item(id: "zz-2")
            item["sourcePrompt"] = "zz \(scalar)"
            let catalog = try Fix.load([Fix.scenario(items: [item, Fix.item(id: "zz-good")])])
            #expect(catalog.issues.map(\.rule) == [.tamilScriptInField(.sourcePrompt)])
        }
    }

    @Test func scriptMayContainSpacesDigitsAndPunctuation() throws {
        let catalog = try loaded(script: "\(Fix.fakeTamil) \(Fix.fakeTamil)?, 1")
        #expect(catalog.issues.isEmpty)
    }

    @Test func scriptWithLatinLettersIsReportedAndTheItemDropped() throws {
        for (language, letters) in [("tamil", Fix.fakeTamil), ("telugu", Fix.fakeTelugu)] {
            for text in ["\(letters) zz", "\(letters)A", "z\(letters)"] {
                let catalog = try loaded(script: text, language: language)
                #expect(catalog.issues.map(\.rule) == [.latinLettersInScript])
                #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
            }
        }
    }

    @Test func emptyScriptIsReported() throws {
        for text in ["", "   "] {
            let catalog = try loaded(script: text)
            #expect(catalog.issues.map(\.rule) == [.emptyField(.script)])
        }
    }

    @Test func scriptWithoutALetterOfTheLessonLanguageIsReported() throws {
        // Just outside each block, and plain digits.
        for text in ["\u{0B7F}", "\u{0C00}", "123"] {
            let tamil = try loaded(script: text)
            #expect(tamil.issues.map(\.rule) == [.scriptMissingNativeLetters])
        }
        for text in ["\u{0BFF}", "\u{0C80}", "123"] {
            let telugu = try loaded(script: text, language: "telugu")
            #expect(telugu.issues.map(\.rule) == [.scriptMissingNativeLetters])
        }
    }

    @Test func scriptBlockBoundariesAreAccepted() throws {
        for text in ["\u{0B80}", "\u{0BFF}"] {
            #expect(try loaded(script: text).issues.isEmpty)
        }
        for text in ["\u{0C00}", "\u{0C7F}"] {
            #expect(try loaded(script: text, language: "telugu").issues.isEmpty)
        }
    }

    @Test func scriptOverTheLengthLimitOrOfTheWrongTypeIsReported() throws {
        let tooLong = String(repeating: "\u{0B85}", count: 501)
        #expect(try loaded(script: tooLong).issues.map(\.rule) == [.fieldTooLong(.script)])
        #expect(try loaded(script: 5).issues.map(\.rule) == [.unknownValue(.script)])
        let atLimit = String(repeating: "\u{0B85}", count: 500)
        #expect(try loaded(script: atLimit).issues.isEmpty)
    }

    @Test func theOldTamilScriptKeyIsIgnoredAndNeverReadAsAFallback() throws {
        let catalog = try loaded(script: nil, extraKeys: ["tamilScript": Fix.fakeTamil])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-1"))?.script == nil)

        // Even a value that would be invalid as `script` is not looked at under the old key.
        let invalid = try loaded(script: nil, extraKeys: ["tamilScript": "zz latin only"])
        #expect(invalid.issues.isEmpty)
        #expect(invalid.item(ItemID(rawValue: "zz-1"))?.script == nil)
    }
}
