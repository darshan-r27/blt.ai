import BLTCatalog
import BLTCore
@testable import BLTContentStore
import Foundation
import Testing

/// Writes fake `zz` content into a unique folder under Application Support (never tmp) and removes it
/// when the test is done.
private struct ContentFolder {
    let url: URL

    init() throws {
        url = URL.applicationSupportDirectory
            .appending(path: "zz-blt-bootstrap-tests", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ name: String, _ text: String) throws {
        try Data(text.utf8).write(to: url.appending(path: name, directoryHint: .notDirectory))
    }

    func makeSubfolder(_ name: String) throws {
        try FileManager.default.createDirectory(
            at: url.appending(path: name, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// A valid one-item scenario file. `itemIDs` are the items in it.
    static func scenarioJSON(scenarioID: String, itemIDs: [String]) -> String {
        let items = itemIDs.map { itemJSON(id: $0) }.joined(separator: ",")
        return """
        {"scenarioId": "\(scenarioID)", "title": "zz title", "subtitle": "zz subtitle", "items": [\(items)]}
        """
    }

    /// A valid item, or an invalid one (no accepted answers) when `broken` is true.
    static func itemJSON(id: String, broken: Bool = false) -> String {
        let accepted = broken ? "[]" : #"["zz canonical \#(id)", "zz canonical b \#(id)", "zz canonical c \#(id)"]"#
        return """
        {"id": "\(id)", "sourcePrompt": "zz prompt \(id)", "register": "respectful", "addressee": "any",
         "canonical": "zz canonical \(id)", "acceptedAnswers": \(accepted), "registerVariant": "zz casual",
         "distractors": ["zz wrong a", "zz wrong b"], "tokens": [{"tamil": "zz", "english": "zz gloss"}],
         "note": null, "reviewStatus": "unreviewed"}
        """
    }
}

struct BootstrapTests {
    @Test func jsonFilesAreEnumeratedInFileNameOrder() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        try folder.write("zz-c.json", "{}")
        try folder.write("zz-a.json", "{}")
        try folder.write("zz-b.json", "{}")
        let files = try #require(BundleContentLoader.jsonFiles(in: folder.url))
        #expect(files.map(\.lastPathComponent) == ["zz-a.json", "zz-b.json", "zz-c.json"])
        #expect(files.allSatisfy { $0.isFileURL })
    }

    @Test func onlyJSONRegularFilesAreLoaded() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        try folder.write("zz-a.json", ContentFolder.scenarioJSON(scenarioID: "zz-s1", itemIDs: ["zz-i1"]))
        try folder.write("zz-notes.txt", "not content")
        try folder.write("zz-b.json.bak", "not content")
        try folder.write("zz-data.JSON", "not content")
        try folder.write(".zz-hidden.json", "not content")
        try folder.makeSubfolder("zz-folder.json")
        let files = try #require(BundleContentLoader.jsonFiles(in: folder.url))
        #expect(files.map(\.lastPathComponent) == ["zz-a.json"])
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(result.fileCount == 1)
        #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-s1"])
        #expect(!result.hasProblems)
    }

    @Test func nonJSONFilesAreIgnoredWithoutIssues() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        try folder.write("zz-readme.txt", "not json at all {")
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(result.fileCount == 0)
        #expect(result.catalog.scenarios.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(result.directoryReadable)
        #expect(!result.hasProblems)
    }

    @Test func emptyDirectoryGivesAnEmptyCatalog() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(result.catalog.scenarios.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(result.fileCount == 0)
        #expect(result.directoryReadable)
    }

    @Test func scenariosFromSeveralFilesAllLoad() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        try folder.write("zz-2.json", ContentFolder.scenarioJSON(scenarioID: "zz-s2", itemIDs: ["zz-i3"]))
        try folder.write("zz-1.json", ContentFolder.scenarioJSON(scenarioID: "zz-s1", itemIDs: ["zz-i1", "zz-i2"]))
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(result.fileCount == 2)
        #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-s1", "zz-s2"])
        #expect(result.catalog.allItemIDs.count == 3)
        #expect(!result.hasProblems)
    }

    @Test func issuesAreSurfacedAndValidSiblingsSurvive() throws {
        let folder = try ContentFolder()
        defer { folder.remove() }
        let mixed = """
        {"scenarioId": "zz-s1", "title": "zz title", "subtitle": "zz subtitle",
         "items": [\(ContentFolder.itemJSON(id: "zz-good")), \(ContentFolder.itemJSON(id: "zz-bad", broken: true))]}
        """
        try folder.write("zz-1.json", mixed)
        try folder.write("zz-2.json", "this is not json")
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(result.hasProblems)
        #expect(result.directoryReadable)
        #expect(result.catalog.allItemIDs == [ItemID(rawValue: "zz-good")])
        #expect(result.skippedItemIDs == [ItemID(rawValue: "zz-bad")])
        #expect(result.skippedItemCount == 1)
        #expect(result.fileOrScenarioIssueCount == 1)
        #expect(result.issues.contains { $0.rule == .malformedJSON })
    }

    @Test func skippedItemsAreCountedOnceHoweverManyRulesTheyBreak() {
        let id = ItemID(rawValue: "zz-item")
        let issues = [
            ContentIssue(fileIndex: 0, scenarioID: nil, itemID: id, rule: .wrongAcceptedCount),
            ContentIssue(fileIndex: 0, scenarioID: nil, itemID: id, rule: .wrongDistractorCount)
        ]
        let result = ContentBootstrapResult(
            catalog: Catalog(scenarios: [], issues: issues),
            fileCount: 1,
            directoryReadable: true
        )
        #expect(result.skippedItemCount == 1)
        #expect(result.fileOrScenarioIssueCount == 0)
    }

    @Test func missingDirectoryIsReportedNotTreatedAsEmptyContent() throws {
        let folder = try ContentFolder()
        folder.remove()
        let result = BundleContentLoader().load(directory: folder.url)
        #expect(!result.directoryReadable)
        #expect(result.hasProblems)
        #expect(result.catalog.scenarios.isEmpty)
    }

    @Test func nonFileURLIsRejected() throws {
        let remote = try #require(URL(string: "zz-scheme://zz-host/zz-content"))
        let result = BundleContentLoader().load(directory: remote)
        #expect(!result.directoryReadable)
        #expect(result.fileCount == 0)
    }

    @Test func bundleWithoutContentFolderIsReportedUnreadable() {
        let result = BundleContentLoader().load(bundle: .main, folder: "zz-no-such-folder")
        #expect(!result.directoryReadable)
        #expect(result.hasProblems)
    }

    @Test func loggedIDsAreCappedAndMarkedWhenTruncated() {
        let ids = (0..<25).map { ItemID(rawValue: "zz-\($0)") }
        let line = ContentBootstrapReporter.loggedIDs(ids)
        #expect(line.hasSuffix(", ..."))
        #expect(line.split(separator: ",").count == ContentBootstrapReporter.maxLoggedIDs + 1)
        #expect(ContentBootstrapReporter.loggedIDs([ids[0]]) == "zz-0")
    }
}
