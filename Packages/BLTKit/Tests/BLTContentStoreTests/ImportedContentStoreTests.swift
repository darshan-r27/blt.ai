import BLTCatalog
import BLTCore
@testable import BLTContentStore
import Foundation
import Testing

struct ImportedContentStoreTests {
    // MARK: Accepting

    @Test func validSingleFileImportAddsANewScenario() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let url = try world.pickScenario("zz-s9", items: ["zz-j1"])

        let summary = try world.store().importFiles([url])

        #expect(summary.scenarioIDs.map(\.rawValue) == ["zz-s9"])
        #expect(summary.count == 1)
        let result = world.layered()
        #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-s1", "zz-s9"])
        #expect(result.fileCount == 2)
        #expect(!result.hasProblems)
    }

    @Test func importReplacesABundledScenarioWithTheSameID() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", title: "zz bundled", items: ["zz-i1"]))
        try world.writeBundled("zz-2.json", ImportWorld.scenarioJSON("zz-s2", items: ["zz-i2"]))
        let url = try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"])

        _ = try world.store().importFiles([url])

        let result = world.layered()
        #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-s1", "zz-s2"])
        #expect(result.catalog.scenarios.first?.title == "zz imported")
        #expect(result.catalog.allItemIDs == [ItemID(rawValue: "zz-i9"), ItemID(rawValue: "zz-i2")])
        #expect(result.fileCount == 2)
        #expect(!result.hasProblems)
    }

    @Test func importingTheSameIDAgainReplacesTheEarlierImport() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s9", title: "zz one", items: ["zz-j1"])])
        _ = try store.importFiles([try world.pickScenario("zz-s9", title: "zz two", items: ["zz-j2"])])

        #expect(store.currentSummary().count == 1)
        #expect(world.importedFileNames().count == 2) // one scenario file plus the manifest
        #expect(world.layered().catalog.scenarios.first?.title == "zz two")
    }

    @Test func aBatchOfSeveralFilesImportsTogether() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let urls = try (1...3).map { index in
            try world.pickScenario("zz-n\(index)", items: ["zz-n\(index)-i"])
        }
        let summary = try world.store().importFiles(urls)
        #expect(summary.scenarioIDs.map(\.rawValue) == ["zz-n1", "zz-n2", "zz-n3"])
    }

    // MARK: Rejecting

    private static func scenarioWithOneItem(_ item: String) -> String {
        ImportWorld.scenarioJSON("zz-s9", rawItems: [item])
    }

    private static let rejectedFiles: [String] = [
        "this is not json {",
        ImportWorld.scenarioJSON("zz-s9", items: []),
        scenarioWithOneItem(ImportWorld.itemJSON(id: "zz-j1", sourcePrompt: "zz \u{0B85}")),
        scenarioWithOneItem(ImportWorld.itemJSON(id: "zz-j1", distractors: #"["zz only one"]"#)),
        scenarioWithOneItem(ImportWorld.itemJSON(id: "zz-j1", accepted: #"["zz canonical"]"#))
    ]

    @Test(arguments: rejectedFiles)
    func rejectsAFileThatBreaksAContentRule(text: String) throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let url = try world.pick("bad.json", text)

        let result = attempt(world.store(), [url])

        #expect(isInvalid(result))
        #expect(world.importedFileNames().isEmpty)
        #expect(world.layered() == BundleContentLoader().load(directory: world.bundled))
    }

    @Test func rejectsAFileOverTheLoadersSizeLimit() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let small = ContentLoader(limits: .init(maxFileBytes: 200, maxItemsPerFile: 200, maxStringLength: 500))
        let url = try world.pickScenario("zz-s9", items: ["zz-j1"])

        #expect(isInvalid(attempt(world.store(loader: small), [url])))
        #expect(world.store().currentSummary().scenarioIDs.isEmpty)
    }

    @Test func rejectsAFileOverTheHardReadCeiling() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let url = try world.pick("huge.json", String(repeating: "zz", count: 600_000))
        #expect(isInvalid(attempt(world.store(), [url])))
    }

    @Test func rejectsAnItemIDAlreadyUsedByAnotherBundledScenario() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let url = try world.pickScenario("zz-s2", items: ["zz-i1"])

        #expect(isInvalid(attempt(world.store(), [url])))
        #expect(world.importedFileNames().isEmpty)
    }

    @Test func rejectsADuplicateItemIDAcrossTwoImportedFiles() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let first = try world.pickScenario("zz-s2", items: ["zz-i1"])
        let second = try world.pickScenario("zz-s3", items: ["zz-i1"])
        #expect(isInvalid(attempt(world.store(), [first, second])))
    }

    @Test func rejectsADuplicateScenarioIDInsideOneBatch() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let first = try world.pickScenario("zz-s2", items: ["zz-i1"])
        let second = try world.pickScenario("zz-s2", items: ["zz-i2"])
        #expect(isInvalid(attempt(world.store(), [first, second])))
        #expect(world.importedFileNames().isEmpty)
    }

    @Test func rejectsMoreThanTenFiles() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let urls = try (1...11).map { index in
            try world.pickScenario("zz-n\(index)", items: ["zz-n\(index)-i"])
        }
        let result = attempt(world.store(), urls)
        #expect(result == .failure(.tooManyFiles(limit: 10)))
        #expect(world.importedFileNames().isEmpty)
    }

    @Test func rejectsZeroFiles() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        #expect(attempt(world.store(), []) == .failure(.noFiles))
    }

    @Test func rejectsANonFileURL() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let remote = try #require(URL(string: "zz-scheme://zz-host/zz.json"))
        #expect(isInvalid(attempt(world.store(), [remote])))
    }

    @Test func reportsAMissingFileAsUnreadable() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let missing = world.picked.appending(path: "zz-missing.json", directoryHint: .notDirectory)
        #expect(attempt(world.store(), [missing]) == .failure(.unreadable))
    }

    @Test func aRejectedBatchLeavesEarlierImportsAndTheCatalogUnchanged() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s9", items: ["zz-j1"])])
        let before = world.layered()
        let namesBefore = world.importedFileNames()

        let good = try world.pickScenario("zz-s8", items: ["zz-k1"])
        let bad = try world.pick("c.json", "not json")
        #expect(isInvalid(attempt(store, [good, bad])))

        #expect(world.layered() == before)
        #expect(world.importedFileNames() == namesBefore)
        #expect(store.currentSummary().scenarioIDs.map(\.rawValue) == ["zz-s9"])
    }

    // MARK: Storage

    @Test func storedFileNamesComeFromTheHashNotTheSourceNameOrID() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let url = try world.pickScenario("../zz-s9", items: ["zz-j1"])

        _ = try world.store().importFiles([url])

        let names = world.importedFileNames()
        #expect(names.contains("imported.json"))
        let stored = names.filter { $0 != "imported.json" }
        #expect(stored.count == 1)
        for name in stored {
            #expect(ImportedContentManifest.isStoredFileName(name))
            #expect(!name.contains("zz"))
            #expect(!name.contains("/"))
        }
    }

    @Test func importsSurviveAFreshStoreInstance() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        _ = try world.store().importFiles([try world.pickScenario("zz-s9", items: ["zz-j1"])])

        let relaunched = world.store()
        #expect(relaunched.currentSummary().scenarioIDs.map(\.rawValue) == ["zz-s9"])
        #expect(world.layered().catalog.scenarios.map(\.id.rawValue) == ["zz-s9"])
    }

    @Test func aStagingFolderLeftByACrashIsSweptOnTheNextImport() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let orphan = world.imported.appending(path: "staging-zz-crashed", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)

        _ = try world.store().importFiles([try world.pickScenario("zz-s9", items: ["zz-j1"])])

        #expect(world.importedFileNames().filter { $0.hasPrefix("staging-") }.isEmpty)
    }
}
