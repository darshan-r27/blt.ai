import BLTCatalog
import BLTContentStore
import BLTCore
import BLTFeatures
import BLTProgress
import BLTSession
import Foundation
import os
import UIKit

/// The one composition root: the only place that chooses concrete types and builds `AppDependencies`.
/// Everything below it receives what it needs by injection.
///
/// The learner's language is only known once the profile has loaded, so this builds the app one language at
/// a time, on request (`Composed.makeCourse`), instead of fixing one language at launch (DECISIONS 043).
struct CompositionRoot {
    /// Subfolder of Application Support that holds the app's own files.
    static let supportFolderName = "BLT"

    /// Folder of Application Support/BLT that holds one folder per language.
    static let coursesFolderName = "courses"

    private static let logger = Logger(subsystem: "ai.blt.app", category: "storage")

    private let arguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
    }

    /// Everything the app's root view needs. `AppDependencies` is a frozen contract, so the profile store
    /// travels beside it rather than inside it.
    struct Composed: Sendable {
        let profileStore: any ProfileStore
        /// The dependencies and the lesson importer for one language. Each call loads that language's catalog
        /// again, so lessons the learner just imported (or removed) take effect in a new root. The progress
        /// stores behind it are built once and reused, so nothing is erased or re-seeded by a reload.
        let makeCourse: @MainActor (CourseLanguage) -> CourseServices
        /// The device-wide daily-practice pieces: reminder choices, the reminder scheduler, either course's
        /// practice log, and the way to this app's page in iOS Settings (DECISIONS 047).
        let practice: PracticeServices
    }

    /// Async because a UI-test launch may have to erase its files before anything reads them.
    func compose() async -> Composed {
        #if DEBUG
        if let fixtures = await UITestLaunch(arguments: arguments).compose() {
            return fixtures
        }
        #endif
        return makeShippingComposition()
    }

    /// `Application Support/BLT`, the folder that holds every file the app writes.
    static var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: supportFolderName, directoryHint: .isDirectory)
    }

    /// `Application Support/BLT/<fileName>`. The folder is created on first write.
    static func supportFileURL(named fileName: String) -> URL {
        supportDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// `Application Support/BLT/courses/<language>/`: everything that belongs to one language.
    static func courseDirectory(for language: CourseLanguage) -> URL {
        supportDirectory
            .appending(path: coursesFolderName, directoryHint: .isDirectory)
            .appending(path: language.rawValue, directoryHint: .isDirectory)
    }

    /// Where one language's progress is kept.
    static func progressFileURL(for language: CourseLanguage) -> URL {
        courseDirectory(for: language).appending(path: "progress.json", directoryHint: .notDirectory)
    }

    /// Where one language's final-exam attempts are kept (DECISIONS 041, 043).
    static func examResultsFileURL(for language: CourseLanguage) -> URL {
        courseDirectory(for: language).appending(path: "exam.json", directoryHint: .notDirectory)
    }

    /// Where one language's finished practice sessions are kept: the streak is computed from this file (DECISIONS 047).
    static func practiceLogFileURL(for language: CourseLanguage) -> URL {
        courseDirectory(for: language).appending(path: "practice.json", directoryHint: .notDirectory)
    }

    /// The learner's reminder choices. One file for the device, not one per course: the choices are about the
    /// phone (notifications, quiet hours), not about a language.
    static var practicePreferencesFileURL: URL {
        supportFileURL(named: "practice-preferences.json")
    }

    /// Opens this app's page in iOS Settings, where the learner can turn notifications back on. The one UIKit call
    /// the daily-practice feature needs: SwiftUI's `openURL` is on the forbidden-API list, and `UIApplication.open`
    /// reaches only the Settings page the system itself names, never a web address.
    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Where one language's imported lesson files live.
    static func importedContentDirectory(for language: CourseLanguage) -> URL {
        courseDirectory(for: language).appending(path: "content", directoryHint: .isDirectory)
    }

    /// Only the shipping composition runs the clean-up: a UI-test launch returns from `compose()` before it gets
    /// here, so a test can never remove real files.
    private func makeShippingComposition() -> Composed {
        sweepLegacyFiles()
        let stores = CourseStores(
            make: { FileProgressStore(fileURL: Self.progressFileURL(for: $0)) },
            makeExam: { FileExamResultStore(fileURL: Self.examResultsFileURL(for: $0)) },
            makePractice: { FilePracticeLogStore(fileURL: Self.practiceLogFileURL(for: $0)) }
        )
        return Composed(
            profileStore: FileProfileStore(fileURL: Self.supportFileURL(named: "profile.json")),
            makeCourse: { language in
                let catalog = Self.loadCatalog(for: language)
                return CourseServices(
                    dependencies: AppDependencies(
                        catalog: catalog,
                        language: language,
                        store: stores.store(for: language),
                        scheduler: SM2Scheduler(),
                        now: { Date.now },
                        examResults: stores.examStore(for: language),
                        examPaper: Self.loadExamPaper(for: language, catalog: catalog),
                        practiceLog: stores.practiceLog(for: language)
                    ),
                    lessonImporter: ImportedContentStore(
                        directory: Self.importedContentDirectory(for: language),
                        bundledDirectory: BundleContentLoader.bundledDirectory(in: .main, language: language),
                        language: language
                    )
                )
            },
            practice: PracticeServices(
                preferences: FilePracticePreferencesStore(fileURL: Self.practicePreferencesFileURL),
                reminders: LocalReminderScheduler(),
                logs: { stores.practiceLog(for: $0) },
                openSystemSettings: { Self.openSystemSettings() }
            )
        )
    }

    /// The course's exam paper (`content/<language>/exam/final.json`, DECISIONS 046), or `nil` when the course has
    /// none yet (no file) or the file was refused. A refused paper is logged by count and never repaired, and Home
    /// then shows no exam, so a learner is never given a short or odd exam. The shipped-content tests guard the
    /// papers that must load.
    private static func loadExamPaper(for language: CourseLanguage, catalog: Catalog) -> ExamPaper? {
        guard let file = Bundle.main.url(
            forResource: "final",
            withExtension: "json",
            subdirectory: "content/\(language.rawValue)/exam"
        ) else { return nil }
        switch ExamPaperLoader(blueprint: .syllabus).load(file: file, catalog: catalog, language: language) {
        case .success(let paper):
            return paper
        case .failure(let failure):
            logger.error("An exam paper was refused with \(failure.issues.count, privacy: .public) problems.")
            assertionFailure("The exam paper has problems; the shipped-content tests list them.")
            return nil
        }
    }

    /// Removes, once, the single-course build's `progress.json` and imported `content/` folder (DECISIONS 043).
    /// Nothing is migrated. A second launch finds nothing. Only counts are logged.
    private func sweepLegacyFiles() {
        let report = LegacyStorageSweep(directory: Self.supportDirectory).run()
        guard !report.foundNothing else { return }
        Self.logger.info(
            """
            Old single-course files removed: progress file \(report.removedProgressFile, privacy: .public), \
            imported lessons folder \(report.removedImportedFolder, privacy: .public) \
            (\(report.importedEntryCount, privacy: .public) entries), failures \(report.failedCount, privacy: .public).
            """
        )
    }

    /// Loads `content/<language>/*.json` from the app bundle with that language's imported lessons layered over
    /// it. A problem is logged (counts, and item IDs marked private) and the valid items are used. In DEBUG an
    /// invalid bundled lesson also stops the app, so a bad content change is noticed immediately; problems in
    /// imported files are skipped files the learner chose, so they never assert. A language whose bundled folder
    /// does not exist yet (Telugu, until its first lessons are drafted) is not a problem to stop for: it loads
    /// as an empty course, which Home explains, and the shipped-content tests guard the folders that must exist.
    private static func loadCatalog(for language: CourseLanguage) -> Catalog {
        #if DEBUG
        let bundledOnly = BundleContentLoader().load(bundle: .main, language: language)
        if bundledOnly.directoryReadable && !bundledOnly.issues.isEmpty {
            assertionFailure("Bundled content has problems; see the 'content' log category.")
        }
        #endif
        let result = BundleContentLoader().load(
            bundle: .main,
            language: language,
            importedDirectory: importedContentDirectory(for: language)
        )
        ContentBootstrapReporter().report(result)
        return result.catalog
    }
}

/// One progress store per language, built once, so a reload of the catalog never creates a second store over
/// the same file. An exhaustive switch rather than a dictionary: a third language would not compile until it
/// has a store.
struct CourseStores: Sendable {
    private let tamil: any ProgressStore
    private let telugu: any ProgressStore
    private let tamilExam: any ExamResultStore
    private let teluguExam: any ExamResultStore
    private let tamilPractice: any PracticeLogStore
    private let teluguPractice: any PracticeLogStore

    /// `makeExam` and `makePractice` default to in-memory stores: only the shipping composition keeps exam
    /// attempts and practice sessions on disk (a UI-test launch keeps its own separate practice files).
    init(
        make: (CourseLanguage) -> any ProgressStore,
        makeExam: (CourseLanguage) -> any ExamResultStore = { _ in InMemoryExamResultStore() },
        makePractice: (CourseLanguage) -> any PracticeLogStore = { _ in InMemoryPracticeLogStore() }
    ) {
        tamil = make(.tamil)
        telugu = make(.telugu)
        tamilExam = makeExam(.tamil)
        teluguExam = makeExam(.telugu)
        tamilPractice = makePractice(.tamil)
        teluguPractice = makePractice(.telugu)
    }

    func store(for language: CourseLanguage) -> any ProgressStore {
        switch language {
        case .tamil: tamil
        case .telugu: telugu
        }
    }

    func examStore(for language: CourseLanguage) -> any ExamResultStore {
        switch language {
        case .tamil: tamilExam
        case .telugu: teluguExam
        }
    }

    nonisolated func practiceLog(for language: CourseLanguage) -> any PracticeLogStore {
        switch language {
        case .tamil: tamilPractice
        case .telugu: teluguPractice
        }
    }
}
