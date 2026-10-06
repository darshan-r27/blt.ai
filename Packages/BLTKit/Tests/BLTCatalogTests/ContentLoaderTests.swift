import BLTCatalog
import BLTCore
import Foundation
import Testing

/// File-level behaviour of `ContentLoader`, using the small fake fixtures under `Fixtures/`.
/// The real `content/` folder is deliberately not read here.
struct ContentLoaderTests {
    private static func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    }

    private static func tempFile(_ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "zz-blt-loader-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "scenario.json", directoryHint: .notDirectory)
        try data.write(to: url)
        return url
    }

    private static func rules(_ catalog: Catalog) -> [ContentIssue.Rule] {
        catalog.issues.map(\.rule)
    }

    // MARK: Happy path and tolerance

    @Test func noFilesGivesAnEmptyCatalog() {
        let catalog = ContentLoader().load(files: [])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues.isEmpty)
    }

    @Test func minimalFixtureLoadsCleanly() throws {
        let catalog = ContentLoader().load(files: [try Self.fixture("valid-minimal")])
        #expect(catalog.issues.isEmpty)
        let scenario = try #require(catalog.scenarios.first)
        #expect(scenario.id == ScenarioID(rawValue: "zz-scenario"))
        #expect(scenario.title == "zz scenario")
        #expect(scenario.subtitle == "zz subtitle")
        #expect(scenario.romanisationNote == nil)
        #expect(scenario.items.map(\.id) == [ItemID(rawValue: "zz-item-1")])
    }

    @Test func unknownKeysAreToleratedAndKnownOptionalKeysAreRead() throws {
        let catalog = ContentLoader().load(files: [try Self.fixture("tolerant-unknown-keys")])
        #expect(catalog.issues.isEmpty)
        let scenario = try #require(catalog.scenarios.first)
        #expect(scenario.romanisationNote == "zz romanisation note")
        #expect(scenario.items.count == 2)
        let casual = try #require(scenario.items.first)
        #expect(casual.register == .casual)
        #expect(casual.addressee == .male)
        #expect(casual.reviewStatus == .reviewed)
        #expect(casual.note == "zz note")
        let neutral = try #require(scenario.items.last)
        #expect(neutral.registerVariant == nil)
        #expect(neutral.distractors.count == 3)
        #expect(neutral.reviewStatus == .unreviewed)
    }

    @Test func latinScriptLoanwordsLoadWithoutIssues() throws {
        let catalog = ContentLoader().load(files: [try Self.fixture("latin-loanwords")])
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.first?.items.first?.canonical == "zz bus GPay pannu")
    }

    // MARK: Survival and ordering

    @Test func invalidItemsAreSkippedAndCountedWhileValidSiblingsSurvive() throws {
        let catalog = ContentLoader().load(files: [try Self.fixture("mixed-valid-invalid")])
        let scenario = try #require(catalog.scenarios.first)
        #expect(scenario.items.map(\.id.rawValue) == ["zz-mixed-1", "zz-mixed-3"])
        #expect(catalog.issues.count == 2)
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 0,
                scenarioID: ScenarioID(rawValue: "zz-mixed"),
                itemID: ItemID(rawValue: "zz-mixed-bad-missing-canonical"),
                rule: .missingField(.canonical)
            ),
            ContentIssue(
                fileIndex: 0,
                scenarioID: ScenarioID(rawValue: "zz-mixed"),
                itemID: ItemID(rawValue: "zz-mixed-bad-status"),
                rule: .unknownValue(.reviewStatus)
            )
        ])
    }

    @Test func scenariosAreSortedByIDRegardlessOfFileOrder() throws {
        let files = [try Self.fixture("sort-b"), try Self.fixture("valid-minimal"), try Self.fixture("sort-a")]
        let catalog = ContentLoader().load(files: files)
        #expect(catalog.issues.isEmpty)
        #expect(catalog.scenarios.map(\.id.rawValue) == ["zz-a-first", "zz-b-second", "zz-scenario"])
    }

    @Test func fileIndexIsThePositionInTheFilesArray() throws {
        let files = [try Self.fixture("valid-minimal"), try Self.fixture("malformed")]
        let catalog = ContentLoader().load(files: files)
        #expect(catalog.scenarios.count == 1)
        #expect(catalog.issues == [ContentIssue(fileIndex: 1, scenarioID: nil, itemID: nil, rule: .malformedJSON)])
    }

    @Test func sameFileLoadedTwiceReportsTheDuplicateScenarioOnTheSecondIndex() throws {
        let file = try Self.fixture("valid-minimal")
        let catalog = ContentLoader().load(files: [file, file])
        #expect(catalog.scenarios.count == 1)
        #expect(catalog.issues == [
            ContentIssue(
                fileIndex: 1, scenarioID: ScenarioID(rawValue: "zz-scenario"), itemID: nil, rule: .duplicateScenarioID
            )
        ])
    }

    // MARK: File-level rules

    @Test func nonFileURLIsRejectedWithoutBeingFetched() throws {
        let url = try #require(URL(string: "zz-scheme://zz.invalid/scenario.json"))
        let catalog = ContentLoader().load(files: [url])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues == [ContentIssue(fileIndex: 0, scenarioID: nil, itemID: nil, rule: .notAFileURL)])
    }

    @Test func missingFileIsReportedAsUnreadable() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "zz-blt-missing-\(UUID().uuidString).json", directoryHint: .notDirectory)
        let catalog = ContentLoader().load(files: [url])
        #expect(catalog.issues == [ContentIssue(fileIndex: 0, scenarioID: nil, itemID: nil, rule: .unreadableFile)])
    }

    @Test func directoryInPlaceOfAFileIsReportedAsUnreadable() {
        let catalog = ContentLoader().load(files: [FileManager.default.temporaryDirectory])
        #expect(Self.rules(catalog) == [.unreadableFile])
    }

    @Test func fileOverOneMegabyteIsRejected() throws {
        let url = try Self.tempFile(Data(repeating: UInt8(ascii: " "), count: 1_048_577))
        let catalog = ContentLoader().load(files: [url])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues == [ContentIssue(fileIndex: 0, scenarioID: nil, itemID: nil, rule: .fileTooLarge)])
    }

    @Test func fileOfExactlyOneMegabyteIsNotRejectedForSize() throws {
        let url = try Self.tempFile(Data(repeating: UInt8(ascii: " "), count: 1_048_576))
        let catalog = ContentLoader().load(files: [url])
        #expect(Self.rules(catalog) == [.malformedJSON])
    }

    @Test func malformedJSONIsReported() throws {
        let catalog = ContentLoader().load(files: [try Self.fixture("malformed")])
        #expect(catalog.scenarios.isEmpty)
        #expect(catalog.issues == [ContentIssue(fileIndex: 0, scenarioID: nil, itemID: nil, rule: .malformedJSON)])
    }

    @Test func jsonWhoseRootIsNotAnObjectIsReportedAsMalformed() throws {
        let url = try Self.tempFile(Data("[1, 2, 3]".utf8))
        #expect(Self.rules(ContentLoader().load(files: [url])) == [.malformedJSON])
    }

    @Test func emptyFileIsReportedAsMalformed() throws {
        let url = try Self.tempFile(Data())
        #expect(Self.rules(ContentLoader().load(files: [url])) == [.malformedJSON])
    }

    @Test func everyKindOfBadFileIsReportedTogetherWithoutThrowing() throws {
        let remote = try #require(URL(string: "zz-scheme://zz.invalid/scenario.json"))
        let files = [remote, try Self.fixture("malformed"), try Self.fixture("valid-minimal")]
        let catalog = ContentLoader().load(files: files)
        #expect(Self.rules(catalog) == [.notAFileURL, .malformedJSON])
        #expect(catalog.scenarios.count == 1)
    }

    // MARK: Limits

    @Test func limitsAreInjectable() throws {
        let file = try Self.fixture("valid-minimal")
        let tinyFile = ContentLoader.Limits(maxFileBytes: 10, maxItemsPerFile: 200, maxStringLength: 500)
        #expect(Self.rules(ContentLoader(limits: tinyFile).load(files: [file])) == [.fileTooLarge])

        let tinyStrings = ContentLoader.Limits(maxFileBytes: 1_048_576, maxItemsPerFile: 200, maxStringLength: 5)
        let strict = ContentLoader(limits: tinyStrings).load(files: [file])
        #expect(strict.scenarios.isEmpty)
        #expect(strict.issues.first?.rule == .fieldTooLong(.scenarioId))
    }

    @Test func defaultLimitsMatchTheContentSchema() {
        #expect(ContentLoader.Limits.default.maxFileBytes == 1_048_576)
        #expect(ContentLoader.Limits.default.maxItemsPerFile == 200)
        #expect(ContentLoader.Limits.default.maxStringLength == 500)
    }
}
