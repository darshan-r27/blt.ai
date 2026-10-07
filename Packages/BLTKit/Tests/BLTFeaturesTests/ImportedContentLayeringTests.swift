import BLTCatalog
import BLTCore
@testable import BLTFeatures
import Foundation
import Testing

struct ImportedContentLayeringTests {
    // MARK: Manifest damage

    @Test func aCorruptManifestMeansNoImports() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"])])
        try Data("{ not a manifest".utf8).write(to: ImportedContentManifest.url(in: world.imported))

        #expect(store.currentSummary().scenarioIDs.isEmpty)
        let result = world.layered()
        #expect(result == BundleContentLoader().load(directory: world.bundled))
        #expect(result.catalog.scenarios.first?.title == "zz title")
    }

    @Test func aMissingManifestMeansNoImports() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s9", items: ["zz-j1"])])
        try FileManager.default.removeItem(at: ImportedContentManifest.url(in: world.imported))

        #expect(store.currentSummary().scenarioIDs.isEmpty)
        #expect(world.layered() == BundleContentLoader().load(directory: world.bundled))
    }

    @Test func aManifestEntryWithAnUnsafeFileNameIsIgnored() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        try FileManager.default.createDirectory(at: world.imported, withIntermediateDirectories: true)
        let manifest = #"{"entries": [{"scenarioId": "zz-s1", "#
            + #""fileName": "../bundled/zz-1.json", "replacesBundledSHA256": null}]}"#
        try Data(manifest.utf8).write(to: ImportedContentManifest.url(in: world.imported))

        #expect(world.store().currentSummary().scenarioIDs.isEmpty)
        #expect(world.layered() == BundleContentLoader().load(directory: world.bundled))
    }

    // MARK: Stale overrides

    @Test func anOverrideIsDroppedWhenTheBundledFileChanges() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-s1", title: "zz old", items: ["zz-i1"])
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"])])
        #expect(world.layered().catalog.scenarios.first?.title == "zz imported")

        try world.writeBundledScenario("zz-s1", title: "zz newer build", items: ["zz-i1"])

        #expect(world.layered().catalog.scenarios.first?.title == "zz newer build")
        #expect(store.currentSummary().scenarioIDs.isEmpty)
    }

    @Test func anOverrideIsDroppedWhenTheBundledScenarioDisappears() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let bundledURL = try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"])])

        try FileManager.default.removeItem(at: bundledURL)

        #expect(world.layered().catalog.scenarios.isEmpty)
        #expect(store.currentSummary().scenarioIDs.isEmpty)
    }

    @Test func aNewIDImportIsIgnoredOnceABundledScenarioTakesTheID() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s9", title: "zz imported", items: ["zz-j1"])])
        #expect(world.layered().catalog.scenarios.count == 1)

        try world.writeBundledScenario("zz-s9", title: "zz now bundled", items: ["zz-b1"])

        let result = world.layered()
        #expect(result.catalog.scenarios.map(\.title) == ["zz now bundled"])
        #expect(!result.hasProblems)
        #expect(store.currentSummary().scenarioIDs.isEmpty)
    }

    @Test func anImportedFileThatNoLongerValidatesIsSkippedAndReported() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-s1", title: "zz bundled", items: ["zz-i1"])
        let store = world.store()
        _ = try store.importFiles([try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"])])
        let stored = world.imported.appending(
            path: ImportedContentManifest.fileName(for: ScenarioID(rawValue: "zz-s1")),
            directoryHint: .notDirectory
        )
        try Data("garbage".utf8).write(to: stored)

        let result = world.layered()

        #expect(result.catalog.scenarios.first?.title == "zz bundled")
        #expect(result.hasProblems)
        #expect(result.issues.contains { $0.rule == .malformedJSON })
    }

    // MARK: Removal

    @Test func removeAllDeletesEveryImportedFileAndTheManifest() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        let store = world.store()
        let urls = [
            try world.pickScenario("zz-s1", title: "zz imported", items: ["zz-i9"]),
            try world.pickScenario("zz-s8", items: ["zz-k1"])
        ]
        _ = try store.importFiles(urls)
        #expect(store.currentSummary().count == 2)

        try store.removeAll()

        #expect(world.importedFileNames().isEmpty)
        #expect(store.currentSummary().scenarioIDs.isEmpty)
        #expect(world.layered() == BundleContentLoader().load(directory: world.bundled))
    }

    @Test func removeAllToleratesMissingFilesAndAnEmptyStore() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let store = world.store()
        try store.removeAll()
        _ = try store.importFiles([try world.pickScenario("zz-s9", items: ["zz-j1"])])
        let stored = world.imported.appending(
            path: ImportedContentManifest.fileName(for: ScenarioID(rawValue: "zz-s9")),
            directoryHint: .notDirectory
        )
        try FileManager.default.removeItem(at: stored)
        try store.removeAll()
        #expect(world.importedFileNames().isEmpty)
    }

    // MARK: Layered load

    @Test func layeredLoadWithNothingImportedEqualsThePlainLoad() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", ImportWorld.scenarioJSON("zz-s1", items: ["zz-i1"]))
        try world.writeBundled("zz-2.json", "not json")

        // The import folder does not exist at all.
        #expect(world.layered() == BundleContentLoader().load(directory: world.bundled))
        #expect(world.layered().hasProblems)
    }

    @Test func layeredLoadOfAMissingBundledFolderIsUnreadable() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let missing = world.root.appending(path: "zz-nothing", directoryHint: .isDirectory)
        let result = BundleContentLoader().load(directory: missing, importedDirectory: world.imported)
        #expect(!result.directoryReadable)
    }

    @Test func aBrokenBundledFileDoesNotBlockAnImportOrLeakIntoItsRejection() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundled("zz-1.json", "not json")
        let url = try world.pickScenario("zz-s9", items: ["zz-j1"])

        let summary = try world.store().importFiles([url])

        #expect(summary.count == 1)
        #expect(world.layered().catalog.scenarios.map(\.id.rawValue) == ["zz-s9"])
    }
}
