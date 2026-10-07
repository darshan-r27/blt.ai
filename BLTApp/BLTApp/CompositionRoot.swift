import BLTCatalog
import BLTFeatures
import BLTProgress
import Foundation

/// The one composition root: the only place that chooses concrete types and builds `AppDependencies`.
/// Everything below it receives what it needs by injection.
struct CompositionRoot {
    /// Subfolder of Application Support that holds the app's own files.
    static let supportFolderName = "BLT"

    private let arguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
    }

    /// Everything the app's root view needs. `AppDependencies` is a frozen contract, so the profile store
    /// travels beside it rather than inside it.
    struct Composed: Sendable {
        let dependencies: AppDependencies
        let profileStore: any ProfileStore
        /// `nil` when the lessons cannot be imported (Settings then hides the Lessons section).
        let lessonImporter: (any LessonImporting)?
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

    /// `Application Support/BLT/<fileName>`. The folder is created on first write.
    static func supportFileURL(named fileName: String) -> URL {
        URL.applicationSupportDirectory
            .appending(path: supportFolderName, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Rebuilds only `AppDependencies`, with the catalog loaded again so lessons the learner just imported
    /// (or removed) take effect. The progress store, scheduler, clock, profile store and importer are reused,
    /// and nothing is erased or re-seeded, so progress and the saved name are untouched.
    ///
    /// A UI-test launch uses a fixed fixture catalog and keeps it.
    func reloaded(_ composed: Composed) -> Composed {
        #if DEBUG
        if arguments.contains(UITestLaunch.fixturesArgument) { return composed }
        #endif
        let old = composed.dependencies
        return Composed(
            dependencies: AppDependencies(
                catalog: loadCatalog(),
                store: old.store,
                scheduler: old.scheduler,
                now: old.now
            ),
            profileStore: composed.profileStore,
            lessonImporter: composed.lessonImporter
        )
    }

    private func makeShippingComposition() -> Composed {
        Composed(
            dependencies: AppDependencies(
                catalog: loadCatalog(),
                store: FileProgressStore(fileURL: Self.supportFileURL(named: "progress.json")),
                scheduler: SM2Scheduler(),
                now: { Date.now }
            ),
            profileStore: FileProfileStore(fileURL: Self.supportFileURL(named: "profile.json")),
            lessonImporter: ImportedContentStore(
                directory: Self.importedContentDirectory,
                bundledDirectory: Bundle.main.url(forResource: "content", withExtension: nil)
            )
        )
    }

    /// Where imported lesson files live, beside the progress and profile files.
    static var importedContentDirectory: URL { supportFileURL(named: "content") }

    /// Loads `content/*.json` from the app bundle with any imported lessons layered over it. A problem is
    /// logged (counts, and item IDs marked private) and the valid items are used. In DEBUG a problem in the
    /// bundled files alone also stops the app, so a bad content change is noticed immediately; problems in
    /// imported files are skipped files the learner chose, so they never assert.
    private func loadCatalog() -> Catalog {
        #if DEBUG
        let bundledOnly = BundleContentLoader().load(bundle: .main)
        if bundledOnly.hasProblems {
            assertionFailure("Bundled content has problems; see the 'content' log category.")
        }
        #endif
        let result = BundleContentLoader().load(bundle: .main, importedDirectory: Self.importedContentDirectory)
        ContentBootstrapReporter().report(result)
        return result.catalog
    }
}
