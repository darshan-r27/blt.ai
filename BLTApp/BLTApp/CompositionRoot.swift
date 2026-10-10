import BLTCatalog
import BLTContentStore
import BLTCore
import BLTFeatures
import BLTProgress
import Foundation
import os

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

    /// Where one language's imported lesson files live.
    static func importedContentDirectory(for language: CourseLanguage) -> URL {
        courseDirectory(for: language).appending(path: "content", directoryHint: .isDirectory)
    }

    /// Only the shipping composition runs the clean-up: a UI-test launch returns from `compose()` before it gets
    /// here, so a test can never remove real files.
    private func makeShippingComposition() -> Composed {
        sweepLegacyFiles()
        let stores = CourseStores { FileProgressStore(fileURL: Self.progressFileURL(for: $0)) }
        return Composed(
            profileStore: FileProfileStore(fileURL: Self.supportFileURL(named: "profile.json")),
            makeCourse: { language in
                CourseServices(
                    dependencies: AppDependencies(
                        catalog: Self.loadCatalog(for: language),
                        language: language,
                        store: stores.store(for: language),
                        scheduler: SM2Scheduler(),
                        now: { Date.now }
                    ),
                    lessonImporter: ImportedContentStore(
                        directory: Self.importedContentDirectory(for: language),
                        bundledDirectory: BundleContentLoader.bundledDirectory(in: .main, language: language),
                        language: language
                    )
                )
            }
        )
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
    /// it. A problem is logged (counts, and item IDs marked private) and the valid items are used. In DEBUG a
    /// problem in the bundled files alone also stops the app, so a bad content change is noticed immediately;
    /// problems in imported files are skipped files the learner chose, so they never assert.
    private static func loadCatalog(for language: CourseLanguage) -> Catalog {
        #if DEBUG
        let bundledOnly = BundleContentLoader().load(bundle: .main, language: language)
        if bundledOnly.hasProblems {
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

    init(make: (CourseLanguage) -> any ProgressStore) {
        tamil = make(.tamil)
        telugu = make(.telugu)
    }

    func store(for language: CourseLanguage) -> any ProgressStore {
        switch language {
        case .tamil: tamil
        case .telugu: telugu
        }
    }
}
