import BLTCatalog
import BLTCore
import Foundation
import Testing

/// One test per content rule in docs/MVP_PLAN.md section 2. Each rule test loads a scenario holding one
/// deliberately broken item and one valid sibling, then checks the exact rules reported and that only the
/// sibling survives. All strings are obviously fake ("zz"); Tamil script appears only as escapes.
struct ContentValidatorTests {
    typealias JSONObject = [String: Any]

    // MARK: Builders

    private static func baseItem(id: String = "zz-bad") -> JSONObject {
        [
            "id": id,
            "sourcePrompt": "zz prompt",
            "register": "respectful",
            "addressee": "any",
            "canonical": "zz canonical",
            "acceptedAnswers": ["zz canonical", "zz canonical b", "zz canonical c"],
            "registerVariant": "zz casual",
            "distractors": ["zz wrong a", "zz wrong b"],
            "tokens": [["tamil": "zz", "english": "zz gloss"]],
            "note": NSNull(),
            "reviewStatus": "unreviewed"
        ]
    }

    private static func scenario(id: String = "zz-scenario", items: [JSONObject]) -> JSONObject {
        ["scenarioId": id, "title": "zz title", "subtitle": "zz subtitle", "items": items]
    }

    private static func write(_ object: JSONObject) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "zz-blt-validator-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "scenario.json", directoryHint: .notDirectory)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        return url
    }

    private static func load(_ scenarios: [JSONObject]) throws -> Catalog {
        try ContentLoader().load(files: scenarios.map(write))
    }

    /// Loads `[broken item, valid sibling]` and expects exactly `rules` reported against the broken item,
    /// with the sibling the only survivor.
    private static func expectRejected(
        _ rules: Set<ContentIssue.Rule>,
        sourceLocation: SourceLocation = #_sourceLocation,
        mutating mutate: (inout JSONObject) -> Void
    ) throws {
        var broken = baseItem()
        mutate(&broken)
        let catalog = try load([scenario(items: [broken, baseItem(id: "zz-good")])])
        #expect(Set(catalog.issues.map(\.rule)) == rules, sourceLocation: sourceLocation)
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")], sourceLocation: sourceLocation)
    }

    // MARK: Baseline

    @Test func validItemProducesNoIssues() throws {
        let catalog = try Self.load([Self.scenario(items: [Self.baseItem()])])
        #expect(catalog.issues.isEmpty)
        let item = try #require(catalog.item(ItemID(rawValue: "zz-bad")))
        #expect(item.scenarioID == ScenarioID(rawValue: "zz-scenario"))
        #expect(item.register == .respectful)
        #expect(item.addressee == .any)
        #expect(item.registerVariant == "zz casual")
        #expect(item.distractors == ["zz wrong a", "zz wrong b"])
        #expect(item.tokens == [Token(tamil: "zz", english: "zz gloss")])
        #expect(item.note == nil)
        #expect(item.reviewStatus == .unreviewed)
    }

    // MARK: Missing, empty, too long, wrong type

    @Test(arguments: [
        ("id", ContentIssue.Field.id),
        ("sourcePrompt", .sourcePrompt),
        ("register", .register),
        ("addressee", .addressee),
        ("canonical", .canonical),
        ("acceptedAnswers", .acceptedAnswers),
        ("distractors", .distractors),
        ("tokens", .tokens),
        ("reviewStatus", .reviewStatus)
    ])
    func missingRequiredFieldIsReportedNeverDefaulted(key: String, field: ContentIssue.Field) throws {
        try Self.expectRejected([.missingField(field)]) { $0.removeValue(forKey: key) }
    }

    @Test func emptyStringFieldIsReported() throws {
        try Self.expectRejected([.emptyField(.canonical)]) { $0["canonical"] = "   " }
    }

    @Test(arguments: [
        ("acceptedAnswers", ContentIssue.Field.acceptedAnswers),
        ("distractors", .distractors),
        ("tokens", .tokens)
    ])
    func emptyArrayFieldIsReported(key: String, field: ContentIssue.Field) throws {
        try Self.expectRejected([.emptyField(field)]) { $0[key] = [Any]() }
    }

    @Test func emptyStringInsideAnArrayIsReported() throws {
        try Self.expectRejected([.emptyField(.distractors)]) { $0["distractors"] = ["zz wrong a", ""] }
    }

    @Test func stringOverFiveHundredCharactersIsReported() throws {
        try Self.expectRejected([.fieldTooLong(.sourcePrompt)]) {
            $0["sourcePrompt"] = String(repeating: "a", count: 501)
        }
    }

    @Test func stringOfExactlyFiveHundredCharactersIsAccepted() throws {
        var item = Self.baseItem()
        item["sourcePrompt"] = String(repeating: "a", count: 500)
        let catalog = try Self.load([Self.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
    }

    @Test func fieldOfTheWrongJSONTypeIsReportedAndSiblingsSurvive() throws {
        try Self.expectRejected([.unknownValue(.id)]) { $0["id"] = 5 }
        try Self.expectRejected([.unknownValue(.distractors)]) { $0["distractors"] = "zz not an array" }
        try Self.expectRejected([.unknownValue(.tokens)]) { $0["tokens"] = [["tamil": "zz", "english": 7]] }
    }

    @Test func itemThatIsNotAnObjectIsReportedAndSiblingsSurvive() throws {
        var raw = Self.scenario(items: [])
        raw["items"] = ["zz not an object", Self.baseItem(id: "zz-good")]
        let catalog = try Self.load([raw])
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
        #expect(catalog.issues.map(\.rule) == [.missingField(.id)])
    }
}

extension ContentValidatorTests {
    // MARK: Tamil script

    @Test func tamilScriptCodePointIsReportedInEveryKindOfField() throws {
        let tamil = "zz\u{0B85}"
        try Self.expectRejected([.tamilScriptInField(.sourcePrompt)]) { $0["sourcePrompt"] = tamil }
        try Self.expectRejected([.tamilScriptInField(.canonical)]) { $0["canonical"] = tamil }
        try Self.expectRejected([.tamilScriptInField(.note)]) { $0["note"] = tamil }
        try Self.expectRejected([.tamilScriptInField(.distractors)]) { $0["distractors"] = [tamil, "zz wrong b"] }
        try Self.expectRejected([.tamilScriptInField(.registerVariant)]) { $0["registerVariant"] = tamil }
        try Self.expectRejected([.tamilScriptInField(.tokens)]) {
            $0["tokens"] = [["tamil": "zz", "english": tamil]]
        }
    }

    @Test func tamilBlockBoundariesAreExact() throws {
        for scalar in ["\u{0B80}", "\u{0BFF}"] {
            try Self.expectRejected([.tamilScriptInField(.sourcePrompt)]) { $0["sourcePrompt"] = "zz \(scalar)" }
        }
        // Just outside the block: the scalar below it and the first Telugu scalar are not Tamil script.
        for scalar in ["\u{0B7F}", "\u{0C00}"] {
            var item = Self.baseItem()
            item["sourcePrompt"] = "zz \(scalar)"
            let catalog = try Self.load([Self.scenario(items: [item])])
            #expect(catalog.issues.isEmpty)
        }
    }

    @Test func latinScriptEnglishLoanwordsAreNotFlagged() throws {
        var item = Self.baseItem()
        item["canonical"] = "zz bus GPay phone"
        item["acceptedAnswers"] = ["zz bus GPay phone", "zz bus GPay phone b", "zz bus GPay phone c"]
        item["tokens"] = [["tamil": "bus", "english": "bus"], ["tamil": "gpay", "english": "GPay"]]
        let catalog = try Self.load([Self.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.first?.items.count == 1)
    }

    // MARK: Enumerated values

    @Test func unknownRegisterAddresseeAndReviewStatusAreReported() throws {
        try Self.expectRejected([.unknownValue(.register)]) { $0["register"] = "zz-unknown" }
        try Self.expectRejected([.unknownValue(.addressee)]) { $0["addressee"] = "zz-unknown" }
        try Self.expectRejected([.unknownValue(.reviewStatus)]) { $0["reviewStatus"] = "zz-unknown" }
    }

    @Test func enumeratedValuesAreCaseSensitive() throws {
        try Self.expectRejected([.unknownValue(.reviewStatus)]) { $0["reviewStatus"] = "Reviewed" }
    }
}

extension ContentValidatorTests {
    // MARK: Options and accepted answers

    @Test func optionsThatCollideCaseInsensitivelyAfterTrimmingAreReported() throws {
        try Self.expectRejected([.duplicateOptionText]) { $0["distractors"] = ["zz wrong a", "  ZZ WRONG A "] }
        try Self.expectRejected([.duplicateOptionText]) { $0["distractors"] = ["zz CASUAL", "zz wrong b"] }
    }

    @Test func wrongDistractorCountIsReported() throws {
        try Self.expectRejected([.wrongDistractorCount]) {
            $0["distractors"] = ["zz wrong a", "zz wrong b", "zz wrong c"]
        }
        try Self.expectRejected([.wrongDistractorCount]) {
            $0["register"] = "neutral"
            $0["registerVariant"] = NSNull()
            $0["distractors"] = ["zz wrong a", "zz wrong b"]
        }
    }

    @Test func neutralItemWithThreeDistractorsAndNoVariantIsValid() throws {
        var item = Self.baseItem()
        item["register"] = "neutral"
        item["registerVariant"] = NSNull()
        item["distractors"] = ["zz wrong a", "zz wrong b", "zz wrong c"]
        let catalog = try Self.load([Self.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.item(ItemID(rawValue: "zz-bad"))?.registerVariant == nil)
    }

    @Test func registerVariantMustBeNilExactlyWhenRegisterIsNeutral() throws {
        try Self.expectRejected([.registerVariantMismatch]) { $0["register"] = "neutral" }
        try Self.expectRejected([.registerVariantMismatch]) {
            $0["registerVariant"] = NSNull()
            $0["distractors"] = ["zz wrong a", "zz wrong b", "zz wrong c"]
        }
    }

    @Test func canonicalMissingFromAcceptedAnswersIsReported() throws {
        try Self.expectRejected([.canonicalNotAccepted]) {
            $0["acceptedAnswers"] = ["zz other a", "zz other b", "zz other c"]
        }
    }

    @Test func canonicalMatchesAcceptedAnswersIgnoringCaseAndWhitespace() throws {
        var item = Self.baseItem()
        item["acceptedAnswers"] = ["  ZZ CANONICAL ", "zz canonical b", "zz canonical c"]
        let catalog = try Self.load([Self.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
    }

    @Test func otherOptionInAcceptedAnswersIsReported() throws {
        try Self.expectRejected([.otherOptionAccepted]) {
            $0["acceptedAnswers"] = ["zz canonical", "zz casual", "zz canonical c"]
        }
        try Self.expectRejected([.otherOptionAccepted]) {
            $0["acceptedAnswers"] = ["zz canonical", "ZZ WRONG A", "zz canonical c"]
        }
    }

    @Test func acceptedAnswerCountOutsideThreeToSixIsReported() throws {
        try Self.expectRejected([.wrongAcceptedCount]) { $0["acceptedAnswers"] = ["zz canonical", "zz b"] }
        try Self.expectRejected([.wrongAcceptedCount]) {
            $0["acceptedAnswers"] = (0..<7).map { "zz canonical \($0)" } + ["zz canonical"]
        }
    }

    @Test func acceptedAnswerCountOfThreeAndSixIsAccepted() throws {
        var six = Self.baseItem(id: "zz-six")
        six["acceptedAnswers"] = ["zz canonical", "zz b", "zz c", "zz d", "zz e", "zz f"]
        let catalog = try Self.load([Self.scenario(items: [Self.baseItem(id: "zz-three"), six])])
        #expect(catalog.issues.isEmpty)
    }

    // MARK: Tokens

    @Test func tokenWordAbsentFromCanonicalIsReported() throws {
        try Self.expectRejected([.tokenNotInCanonical]) {
            $0["tokens"] = [["tamil": "zz", "english": "zz gloss"], ["tamil": "qq", "english": "zz gloss"]]
        }
    }

    @Test func tokenWordMatchesCanonicalIgnoringCase() throws {
        var item = Self.baseItem()
        item["tokens"] = [["tamil": "CANONICAL", "english": "zz gloss"]]
        let catalog = try Self.load([Self.scenario(items: [item])])
        #expect(catalog.issues.isEmpty)
    }
}

extension ContentValidatorTests {
    // MARK: Scenario level

    @Test func missingScenarioHeaderFieldsDropTheScenarioAndAreReported() throws {
        let headerFields: [(String, ContentIssue.Field)] = [
            ("scenarioId", .scenarioId), ("title", .title), ("subtitle", .subtitle)
        ]
        for (key, field) in headerFields {
            var raw = Self.scenario(items: [Self.baseItem()])
            raw.removeValue(forKey: key)
            let catalog = try Self.load([raw])
            #expect(catalog.scenarios.isEmpty)
            #expect(catalog.issues.map(\.rule) == [.missingField(field)])
        }
    }

    @Test func romanisationNoteIsKeptWhenPresentAndHeaderChecksApplyToIt() throws {
        var raw = Self.scenario(items: [Self.baseItem()])
        raw["romanisationNote"] = "zz note"
        let kept = try Self.load([raw])
        #expect(kept.scenarios.first?.romanisationNote == "zz note")

        raw["romanisationNote"] = "zz\u{0B85}"
        let rejected = try Self.load([raw])
        #expect(rejected.scenarios.isEmpty)
        #expect(rejected.issues.map(\.rule) == [.tamilScriptInField(.note)])
    }

    @Test func scenarioWithNoValidItemsIsDroppedWithAnEmptyScenarioIssue() throws {
        var broken = Self.baseItem()
        broken["canonical"] = NSNull()
        let catalog = try Self.load([Self.scenario(items: [broken])])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.missingField(.canonical), .emptyScenario])
    }

    @Test func scenarioWithAnEmptyOrMissingItemsArrayIsDropped() throws {
        let empty = try Self.load([Self.scenario(items: [])])
        #expect(empty.scenarios.isEmpty)
        #expect(empty.issues.map(\.rule) == [.emptyScenario])

        var missing = Self.scenario(items: [])
        missing.removeValue(forKey: "items")
        let none = try Self.load([missing])
        #expect(none.scenarios.isEmpty)
        #expect(none.issues.map(\.rule) == [.emptyScenario])
    }

    @Test func moreThanTwoHundredItemsInAFileIsRejected() throws {
        let items = (0..<201).map { Self.baseItem(id: "zz-\($0)") }
        let catalog = try Self.load([Self.scenario(items: items)])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.map(\.rule) == [.tooManyItems])
    }

    @Test func exactlyTwoHundredItemsInAFileIsAccepted() throws {
        let items = (0..<200).map { Self.baseItem(id: "zz-\($0)") }
        let catalog = try Self.load([Self.scenario(items: items)])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.first?.items.count == 200)
    }

    // MARK: Duplicates

    @Test func duplicateItemIDWithinAFileKeepsTheFirstOnly() throws {
        var second = Self.baseItem(id: "zz-same")
        second["canonical"] = "zz second canonical"
        second["acceptedAnswers"] = ["zz second canonical", "zz second b", "zz second c"]
        second["tokens"] = [["tamil": "zz second", "english": "zz gloss"]]
        let catalog = try Self.load([Self.scenario(items: [Self.baseItem(id: "zz-same"), second])])
        #expect(catalog.issues.map(\.rule) == [.duplicateItemID])
        #expect(catalog.scenarios.first?.items.map(\.canonical) == ["zz canonical"])
    }

    @Test func duplicateItemIDAcrossFilesKeepsTheEarlierFile() throws {
        let first = Self.scenario(id: "zz-first", items: [Self.baseItem(id: "zz-same"), Self.baseItem(id: "zz-one")])
        let second = Self.scenario(id: "zz-second", items: [Self.baseItem(id: "zz-same"), Self.baseItem(id: "zz-two")])
        let catalog = try Self.load([first, second])
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1,
                scenarioID: ScenarioID(rawValue: "zz-second"),
                itemID: ItemID(rawValue: "zz-same"),
                rule: .duplicateItemID
            )
        ])
        #expect(catalog.allItemIDs.count == 3)
    }

    @Test func duplicateScenarioIDAcrossFilesDropsTheLaterScenario() throws {
        let first = Self.scenario(id: "zz-same", items: [Self.baseItem(id: "zz-one")])
        let second = Self.scenario(id: "zz-same", items: [Self.baseItem(id: "zz-two")])
        let catalog = try Self.load([first, second])
        #expect(catalog.scenarios.count == 1)
        #expect(catalog.allItemIDs == [ItemID(rawValue: "zz-one")])
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1, scenarioID: ScenarioID(rawValue: "zz-same"), itemID: nil, rule: .duplicateScenarioID
            )
        ])
    }

    // MARK: Issue attribution

    @Test func issuesCarryTheScenarioAndItemIDsAndFileIndex() throws {
        let good = Self.scenario(id: "zz-good", items: [Self.baseItem(id: "zz-ok")])
        var broken = Self.baseItem(id: "zz-broken")
        broken["reviewStatus"] = "zz-unknown"
        let bad = Self.scenario(id: "zz-bad", items: [broken, Self.baseItem(id: "zz-fine")])
        let catalog = try Self.load([good, bad])
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1,
                scenarioID: ScenarioID(rawValue: "zz-bad"),
                itemID: ItemID(rawValue: "zz-broken"),
                rule: .unknownValue(.reviewStatus)
            )
        ])
    }
}
