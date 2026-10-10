import BLTCatalog
import BLTCore
import Foundation
import Testing

/// The required lesson-level `language`, the wrong-course rejection and the `word` gloss key
/// (DECISIONS 044). All text is obviously fake ("zz").
struct CatalogLanguageTests {
    private typealias Fix = CatalogFormatFixtures

    private func lesson(
        id: String = "zz-scenario",
        language: String?,
        itemID: String = "zz-1"
    ) -> [String: Any] {
        Fix.scenario(id: id, language: language, items: [Fix.item(id: itemID)])
    }

    // MARK: language is required and known

    @Test func languageIsReadIntoTheScenario() throws {
        let tamil = try Fix.load([lesson(language: "tamil")])
        #expect(tamil.issues.isEmpty)
        #expect(tamil.scenarios.first?.language == .tamil)

        let telugu = try Fix.load([lesson(language: "telugu")])
        #expect(telugu.issues.isEmpty)
        #expect(telugu.scenarios.first?.language == .telugu)
    }

    @Test func missingLanguageDropsTheLessonAndIsReported() throws {
        let catalog = try Fix.load([lesson(language: nil)])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.missingField(.language)])
    }

    @Test func unknownLanguageDropsTheLessonAndIsReported() throws {
        for value in ["zz", "Tamil", "hindi"] {
            let catalog = try Fix.load([lesson(language: value)])
            #expect(catalog.scenarios.isEmpty, "language \(value)")
            #expect(catalog.issues.map(\.rule) == [.unknownValue(.language)], "language \(value)")
        }
        let empty = try Fix.load([lesson(language: "")])
        #expect(empty.scenarios.isEmpty)
        #expect(empty.issues.map(\.rule) == [.emptyField(.language)])
    }

    @Test func languageOfTheWrongJSONTypeIsReported() throws {
        var raw = lesson(language: nil)
        raw["language"] = 7
        let catalog = try Fix.load([raw])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.unknownValue(.language)])
    }

    // MARK: the course's language

    @Test func noExpectedLanguageAcceptsBothLanguages() throws {
        let catalog = try Fix.load([
            lesson(id: "zz-a", language: "tamil", itemID: "zz-a1"),
            lesson(id: "zz-b", language: "telugu", itemID: "zz-b1")
        ])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.map(\.language) == [.tamil, .telugu])
    }

    @Test func aLessonInTheWrongCourseIsRejectedAndLoadsNothing() throws {
        let catalog = try Fix.load([lesson(language: "telugu")], expectedLanguage: .tamil)
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.allItemIDs.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.wrongLanguage])
        #expect(catalog.issues.first?.scenarioID == ScenarioID(rawValue: "zz-scenario"))

        let other = try Fix.load([lesson(language: "tamil")], expectedLanguage: .telugu)
        #expect(other.scenarios.isEmpty)
        #expect(other.issues.map(\.rule) == [.wrongLanguage])
    }

    @Test func aLessonInTheRightCourseIsAccepted() throws {
        for language in CourseLanguage.allCases {
            let catalog = try Fix.load([lesson(language: language.rawValue)], expectedLanguage: language)
            #expect(catalog.issues.isEmpty)
            #expect(catalog.scenarios.count == 1)
        }
    }

    @Test func aRejectedLessonLeavesNoTraceForTheDuplicateChecks() throws {
        // The Telugu lesson is rejected first, so a later Tamil lesson with the same ids and text loads clean.
        let catalog = try Fix.load(
            [lesson(language: "telugu"), lesson(language: "tamil")],
            expectedLanguage: .tamil
        )
        #expect(catalog.issues.map(\.rule) == [.wrongLanguage])
        #expect(catalog.issues.first?.fileIndex == 0)
        #expect(catalog.scenarios.map(\.language) == [.tamil])
    }

    @Test func aWrongCourseLessonDoesNotHideOtherValidLessons() throws {
        let catalog = try Fix.load(
            [
                lesson(id: "zz-a", language: "telugu", itemID: "zz-a1"),
                lesson(id: "zz-b", language: "tamil", itemID: "zz-b1")
            ],
            expectedLanguage: .tamil
        )
        #expect(catalog.scenarios.map(\.id) == [ScenarioID(rawValue: "zz-b")])
        #expect(catalog.issues.map(\.rule) == [.wrongLanguage])
    }

    @Test func duplicateRulesStillApplyWithinOneLoad() throws {
        let first = Fix.scenario(id: "zz-a", language: "tamil", items: [Fix.item(id: "zz-a1", prompt: "zz same")])
        let second = Fix.scenario(id: "zz-b", language: "tamil", items: [Fix.item(id: "zz-b1", prompt: "zz same")])
        let catalog = try Fix.load([first, second], expectedLanguage: .tamil)
        // The later lesson's only item is dropped, so the lesson itself is reported empty as well.
        #expect(catalog.issues.map(\.rule) == [.duplicateSourcePrompt, .emptyScenario])
        #expect(catalog.scenarios.map(\.id) == [ScenarioID(rawValue: "zz-a")])
    }

    // MARK: the gloss key

    @Test func wordIsTheGlossKey() throws {
        let catalog = try Fix.load([lesson(language: "tamil")])
        #expect(catalog.issues.isEmpty)
        let token = try #require(catalog.item(ItemID(rawValue: "zz-1"))?.tokens.first)
        #expect(token.word == "zz")
        #expect(token.tamil == "zz")
    }

    @Test func theOldTamilGlossKeyIsAnErrorNotAFallback() throws {
        var item = Fix.item(id: "zz-1")
        item["tokens"] = [["tamil": "zz", "english": "zz gloss"]]
        let catalog = try Fix.load([Fix.scenario(items: [item, Fix.item(id: "zz-good")])])
        #expect(catalog.issues.map(\.rule) == [.missingField(.tokens)])
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
    }

    @Test func wordWinsOverAStrayTamilKey() throws {
        var item = Fix.item(id: "zz-1")
        item["tokens"] = [["word": "zz", "tamil": "qq", "english": "zz gloss"]]
        let catalog = try Fix.load([Fix.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-1"))?.tokens.first?.word == "zz")
    }
}
