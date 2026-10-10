import BLTCatalog
import BLTContentStore
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// A fake importer: returns what it is told to and counts the calls. Fake ids only.
private actor FakeLessonImporter: LessonImporting {
    private let importResult: Result<ImportedContentSummary, ContentImportFailure>
    private let removeError: ContentImportFailure?
    private var active: ImportedContentSummary
    private(set) var importCalls: [[URL]] = []
    private(set) var removeCalls = 0

    init(
        importResult: Result<ImportedContentSummary, ContentImportFailure> = .success(
            ImportedContentSummary(scenarioIDs: [ScenarioID(rawValue: "zz-a"), ScenarioID(rawValue: "zz-b")])
        ),
        removeError: ContentImportFailure? = nil,
        active: ImportedContentSummary = ImportedContentSummary(scenarioIDs: [])
    ) {
        self.importResult = importResult
        self.removeError = removeError
        self.active = active
    }

    func importFiles(_ urls: [URL]) async throws(ContentImportFailure) -> ImportedContentSummary {
        importCalls.append(urls)
        let summary = try importResult.get()
        active = summary
        return summary
    }

    func removeAll() async throws(ContentImportFailure) {
        removeCalls += 1
        if let removeError { throw removeError }
        active = ImportedContentSummary(scenarioIDs: [])
    }

    func currentSummary() async -> ImportedContentSummary { active }
}

/// Records the lesson changes the owner was told about.
@MainActor
private final class LessonChangeLog {
    private(set) var changes: [LessonChange] = []
    func record(_ change: LessonChange) { changes.append(change) }
}

private struct PickerFailure: Error {}

@MainActor
private func makeModel(
    importer: (any LessonImporting)?,
    log: LessonChangeLog = LessonChangeLog(),
    language: CourseLanguage? = nil
) -> SettingsViewModel {
    SettingsViewModel(
        dependencies: AppDependencies(
            catalog: Catalog(scenarios: [], issues: []),
            language: .tamil,
            store: InMemoryProgressStore(),
            scheduler: SM2Scheduler(),
            now: { Date(timeIntervalSince1970: 1_000_000) }
        ),
        profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
        profileName: "zz Sample",
        lessonImporter: importer,
        onDidChangeLessons: { log.record($0) },
        learningLanguage: language
    )
}

private let pickedFile = URL(fileURLWithPath: "/zz/picked.json")

@MainActor
struct SettingsImportViewModelTests {
    @Test func lessonsSectionIsHiddenWithoutAnImporter() async {
        let model = makeModel(importer: nil)
        #expect(model.canImportLessons == false)
        await model.refreshImportedSummary()
        #expect(model.importedCount == 0)
        await model.importLessons(from: .success([pickedFile]))
        #expect(model.importOutcome == nil)
        await model.removeImported()
        #expect(model.importOutcome == nil)
    }

    @Test func lessonsSectionIsShownWithAnImporter() {
        #expect(makeModel(importer: FakeLessonImporter()).canImportLessons)
    }

    @Test func refreshReadsTheActiveImportCount() async {
        let active = ImportedContentSummary(scenarioIDs: [ScenarioID(rawValue: "zz-a")])
        let model = makeModel(importer: FakeLessonImporter(active: active))
        #expect(model.importedCount == 0)
        await model.refreshImportedSummary()
        #expect(model.importedCount == 1)
        #expect(model.importedCountMessage == "1 imported lesson is in use.")
    }

    @Test func noCountMessageWhenNothingIsImported() async {
        let model = makeModel(importer: FakeLessonImporter())
        await model.refreshImportedSummary()
        #expect(model.importedCountMessage == nil)
    }

    @Test func successfulImportReportsTheCountAndNotifiesTheOwner() async {
        let importer = FakeLessonImporter()
        let log = LessonChangeLog()
        let model = makeModel(importer: importer, log: log)
        await model.importLessons(from: .success([pickedFile]))
        #expect(model.importOutcome == .succeeded(count: 2))
        #expect(model.importedCount == 2)
        #expect(model.importedCountMessage == "2 imported lessons are in use.")
        #expect(model.isImporting == false)
        #expect(log.changes == [.imported(scenarioCount: 2)])
        #expect(await importer.importCalls == [[pickedFile]])
    }

    @Test func eachFailureMapsToItsOutcomeAndDoesNotNotifyTheOwner() async {
        let failures: [(ContentImportFailure, String)] = [
            (.noFiles, "No file was chosen."),
            (.tooManyFiles(limit: 10), "Choose up to 10 files at a time."),
            (.unreadable, "A file could not be read. If it is in iCloud Drive, download it first."),
            (
                .invalid(issueCount: 3),
                "Nothing was imported: the file did not pass the lesson checks (3 problems). "
                    + "Your lessons are unchanged."
            ),
            (
                .invalid(issueCount: 1),
                "Nothing was imported: the file did not pass the lesson checks (1 problem). "
                    + "Your lessons are unchanged."
            ),
            (.couldNotSave, "The lessons could not be saved. Your lessons are unchanged.")
        ]
        for (failure, message) in failures {
            let log = LessonChangeLog()
            let model = makeModel(importer: FakeLessonImporter(importResult: .failure(failure)), log: log)
            await model.importLessons(from: .success([pickedFile]))
            #expect(model.importOutcome == .failed(failure))
            #expect(model.importStatusMessage == message)
            #expect(model.importedCount == 0)
            #expect(model.isImporting == false)
            #expect(log.changes.isEmpty)
        }
    }

    @Test func aFileForTheOtherLanguageIsNamedPlainlyAndChangesNothing() async {
        let cases: [(CourseLanguage?, String)] = [
            (
                .tamil,
                "That file is for Telugu, not Tamil. Nothing was imported and your lessons are unchanged."
            ),
            (
                .telugu,
                "That file is for Tamil, not Telugu. Nothing was imported and your lessons are unchanged."
            ),
            (
                nil,
                "That file is for the other language. Nothing was imported and your lessons are unchanged."
            )
        ]
        for (language, message) in cases {
            let log = LessonChangeLog()
            let model = makeModel(
                importer: FakeLessonImporter(importResult: .failure(.wrongLanguage)),
                log: log,
                language: language
            )
            await model.importLessons(from: .success([pickedFile]))
            #expect(model.importOutcome == .failed(.wrongLanguage))
            #expect(model.importStatusMessage == message)
            #expect(model.importedCount == 0)
            #expect(log.changes.isEmpty)
        }
    }

    @Test func aCancelledPickerDoesNothing() async {
        let importer = FakeLessonImporter()
        let log = LessonChangeLog()
        let model = makeModel(importer: importer, log: log)
        await model.importLessons(from: .failure(CocoaError(.userCancelled)))
        #expect(model.importOutcome == nil)
        #expect(await importer.importCalls.isEmpty)
        #expect(log.changes.isEmpty)
    }

    @Test func aCancelledPickerKeepsTheEarlierMessage() async {
        let model = makeModel(importer: FakeLessonImporter(importResult: .failure(.noFiles)))
        await model.importLessons(from: .success([]))
        await model.importLessons(from: .failure(CocoaError(.userCancelled)))
        #expect(model.importOutcome == .failed(.noFiles))
    }

    @Test func aPickerErrorMapsToUnreadable() async {
        let importer = FakeLessonImporter()
        let log = LessonChangeLog()
        let model = makeModel(importer: importer, log: log)
        await model.importLessons(from: .failure(PickerFailure()))
        #expect(model.importOutcome == .failed(.unreadable))
        #expect(await importer.importCalls.isEmpty)
        #expect(log.changes.isEmpty)
    }

    @Test func aNewImportClearsTheEarlierFailure() async {
        let model = makeModel(importer: FakeLessonImporter())
        await model.importLessons(from: .failure(PickerFailure()))
        await model.importLessons(from: .success([pickedFile]))
        #expect(model.importOutcome == .succeeded(count: 2))
    }

    @Test func requestingRemovalRemovesNothing() async {
        let importer = FakeLessonImporter()
        let model = makeModel(importer: importer)
        model.requestRemoveImported()
        #expect(model.isConfirmingRemoveImported)
        #expect(await importer.removeCalls == 0)
    }

    @Test func removalSucceedsClearsTheCountAndNotifiesTheOwner() async {
        let active = ImportedContentSummary(scenarioIDs: [ScenarioID(rawValue: "zz-a")])
        let importer = FakeLessonImporter(active: active)
        let log = LessonChangeLog()
        let model = makeModel(importer: importer, log: log)
        await model.refreshImportedSummary()
        model.requestRemoveImported()
        await model.removeImported()
        #expect(model.isConfirmingRemoveImported == false)
        #expect(model.importedCount == 0)
        #expect(model.importOutcome == nil)
        #expect(log.changes == [.removed])
        #expect(await importer.removeCalls == 1)
    }

    @Test func removalFailureIsSurfacedKeepsTheCountAndDoesNotNotifyTheOwner() async {
        let active = ImportedContentSummary(scenarioIDs: [ScenarioID(rawValue: "zz-a")])
        let importer = FakeLessonImporter(removeError: .couldNotSave, active: active)
        let log = LessonChangeLog()
        let model = makeModel(importer: importer, log: log)
        await model.refreshImportedSummary()
        model.requestRemoveImported()
        await model.removeImported()
        #expect(model.importOutcome == .failed(.couldNotSave))
        #expect(model.importedCount == 1)
        #expect(log.changes.isEmpty)
    }

    @Test func theRealStoreWorksThroughTheAsyncProtocol() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "zz-import-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let importer: any LessonImporting = ImportedContentStore(
            directory: directory,
            bundledDirectory: nil,
            language: .tamil
        )
        #expect(await importer.currentSummary().scenarioIDs.isEmpty)
        do {
            _ = try await importer.importFiles([])
            Issue.record("Importing no files should fail")
        } catch {
            #expect(error == .noFiles)
        }
        try await importer.removeAll()
        #expect(await importer.currentSummary().scenarioIDs.isEmpty)
    }
}
