import BLTCatalog
import BLTCore
@testable import BLTContentStore
import Foundation
import Testing

/// One course per learner (DECISIONS 043, 044): bundled and imported lessons are loaded per language, and a
/// lesson written for the other course is rejected. All text is fake (`zz`); the language is only the
/// `language` field.
struct ImportedContentLanguageTests {
    // MARK: Bundled folders per language

    /// A throwaway bundle laid out as `content/<language>/*.json`.
    private func makeBundle(in world: ImportWorld, languages: [CourseLanguage]) throws -> Bundle {
        let bundleURL = world.root.appending(path: "zz.bundle", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        for language in languages {
            let folder = bundleURL
                .appending(path: "content", directoryHint: .isDirectory)
                .appending(path: language.rawValue, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let json = ImportWorld.scenarioJSON("zz-\(language.rawValue)-s1", language: language, items: ["zz-i1"])
            try Data(json.utf8).write(to: folder.appending(path: "zz-1.json", directoryHint: .notDirectory))
        }
        return try #require(Bundle(url: bundleURL))
    }

    @Test func eachCourseLoadsOnlyItsOwnBundledFolder() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let bundle = try makeBundle(in: world, languages: CourseLanguage.allCases)

        for language in CourseLanguage.allCases {
            let result = BundleContentLoader().load(bundle: bundle, language: language)
            #expect(result.directoryReadable)
            #expect(!result.hasProblems)
            #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-\(language.rawValue)-s1"])
            #expect(result.catalog.scenarios.allSatisfy { $0.language == language })
        }
    }

    @Test func aMissingLanguageFolderIsAnEmptyCatalogNotACrash() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let bundle = try makeBundle(in: world, languages: [.tamil])

        let plain = BundleContentLoader().load(bundle: bundle, language: .telugu)
        let layered = BundleContentLoader().load(bundle: bundle, language: .telugu, importedDirectory: world.imported)

        for result in [plain, layered] {
            #expect(!result.directoryReadable)
            #expect(result.fileCount == 0)
            #expect(result.catalog.scenarios.isEmpty)
        }
        #expect(BundleContentLoader.bundledDirectory(in: bundle, language: .telugu) == nil)
        #expect(BundleContentLoader.bundledDirectory(in: bundle, language: .tamil) != nil)
    }

    @Test func aLessonOfTheOtherCourseInABundledFolderIsRejected() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-own", language: .tamil, items: ["zz-i1"])
        try world.writeBundledScenario("zz-other", language: .telugu, items: ["zz-j1"])

        let result = BundleContentLoader().load(directory: world.bundled, language: .tamil)

        #expect(result.catalog.scenarios.map(\.id.rawValue) == ["zz-own"])
        #expect(result.issues.map(\.rule) == [.wrongLanguage])
    }

    // MARK: Importing into a course

    @Test func aTeluguFileImportedIntoTheTamilCourseIsRejectedAndNothingChanges() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-s1", title: "zz bundled", language: .tamil, items: ["zz-i1"])
        let store = world.store(language: .tamil)
        let url = try world.pickScenario("zz-s9", language: .telugu, items: ["zz-j1"])

        let result = attempt(store, [url])

        #expect(result == .failure(.invalid(issueCount: 1)))
        #expect(world.importedFileNames().isEmpty)
        #expect(store.currentSummary().scenarioIDs.isEmpty)
        #expect(world.layered(language: .tamil).catalog.scenarios.map(\.title) == ["zz bundled"])
    }

    @Test func aTamilFileImportedIntoTheTeluguCourseIsRejectedAndNothingChanges() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-s1", title: "zz bundled", language: .telugu, items: ["zz-i1"])
        let store = world.store(language: .telugu)
        let url = try world.pickScenario("zz-s9", language: .tamil, items: ["zz-j1"])

        let result = attempt(store, [url])

        #expect(result == .failure(.invalid(issueCount: 1)))
        #expect(world.importedFileNames().isEmpty)
        #expect(store.currentSummary().scenarioIDs.isEmpty)
    }

    @Test func oneWrongLanguageFileRejectsTheWholeBatch() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let store = world.store(language: .telugu)
        let good = try world.pickScenario("zz-s8", language: .telugu, items: ["zz-k1"])
        let wrong = try world.pickScenario("zz-s9", language: .tamil, items: ["zz-j1"])

        #expect(isInvalid(attempt(store, [good, wrong])))
        #expect(world.importedFileNames().isEmpty)

        // The same batch without the wrong file imports.
        #expect(try store.importFiles([good]).scenarioIDs == [ScenarioID(rawValue: "zz-s8")])
    }

    @Test func aFileOfTheCoursesOwnLanguageImports() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        let store = world.store(language: .telugu)
        let url = try world.pickScenario("zz-s9", language: .telugu, items: ["zz-j1"])

        #expect(try store.importFiles([url]).count == 1)
        #expect(world.layered(language: .telugu).catalog.scenarios.map(\.id.rawValue) == ["zz-s9"])
    }

    // MARK: Layered load

    @Test func anImportOfTheOtherCourseOnDiskIsSkippedAndReportedWhenLoading() throws {
        let world = try ImportWorld()
        defer { world.remove() }
        try world.writeBundledScenario("zz-s1", title: "zz bundled", language: .tamil, items: ["zz-i1"])
        // A store with no course accepts either language (the transitional default), so this puts a
        // Telugu file into the import folder that a Tamil load must then refuse to show.
        let anyCourse = world.store(language: nil)
        let other = try world.pickScenario("zz-s1", title: "zz imported", language: .telugu, items: ["zz-j1"])
        _ = try anyCourse.importFiles([other])

        let result = world.layered(language: .tamil)

        #expect(result.catalog.scenarios.map(\.title) == ["zz bundled"])
        #expect(result.issues.contains { $0.rule == .wrongLanguage })
    }

    // MARK: Stale overrides, per language

    @Test func theStaleRuleUsesEachLanguagesOwnBundledFolder() throws {
        let tamil = try ImportWorld()
        let telugu = try ImportWorld()
        defer {
            tamil.remove()
            telugu.remove()
        }
        // The same scenario id in both courses, each with its own bundled folder and import folder.
        try tamil.writeBundledScenario("zz-s1", title: "zz old", language: .tamil, items: ["zz-i1"])
        try telugu.writeBundledScenario("zz-s1", title: "zz old", language: .telugu, items: ["zz-i1"])
        let tamilStore = tamil.store(language: .tamil)
        let teluguStore = telugu.store(language: .telugu)
        let tamilFile = try tamil.pickScenario("zz-s1", title: "zz imported", language: .tamil, items: ["zz-i9"])
        let teluguFile = try telugu.pickScenario("zz-s1", title: "zz imported", language: .telugu, items: ["zz-i9"])
        _ = try tamilStore.importFiles([tamilFile])
        _ = try teluguStore.importFiles([teluguFile])
        #expect(tamil.layered(language: .tamil).catalog.scenarios.first?.title == "zz imported")
        #expect(telugu.layered(language: .telugu).catalog.scenarios.first?.title == "zz imported")

        // A new build changes only the Telugu bundled file.
        try telugu.writeBundledScenario("zz-s1", title: "zz newer build", language: .telugu, items: ["zz-i1"])

        #expect(tamil.layered(language: .tamil).catalog.scenarios.first?.title == "zz imported")
        #expect(tamilStore.currentSummary().count == 1)
        #expect(telugu.layered(language: .telugu).catalog.scenarios.first?.title == "zz newer build")
        #expect(teluguStore.currentSummary().scenarioIDs.isEmpty)
    }

    // MARK: Limit

    @Test func theImportLimitIsTwentyFiles() throws {
        #expect(ImportedContentStore.maxFilesPerImport == 20)
        let world = try ImportWorld()
        defer { world.remove() }
        let urls = try (1...20).map { index in
            try world.pickScenario("zz-n\(index)", items: ["zz-n\(index)-i"])
        }

        #expect(try world.store().importFiles(urls).count == 20)

        let tooMany = try (1...21).map { index in
            try world.pickScenario("zz-m\(index)", items: ["zz-m\(index)-i"])
        }
        #expect(attempt(world.store(), tooMany) == .failure(.tooManyFiles(limit: 20)))
    }
}
