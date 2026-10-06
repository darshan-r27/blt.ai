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

    private func makeShippingComposition() -> Composed {
        Composed(
            dependencies: AppDependencies(
                catalog: loadBundledCatalog(),
                store: FileProgressStore(fileURL: Self.supportFileURL(named: "progress.json")),
                scheduler: SM2Scheduler(),
                now: { Date.now }
            ),
            profileStore: FileProfileStore(fileURL: Self.supportFileURL(named: "profile.json"))
        )
    }

    /// Loads `content/*.json` from the app bundle. In DEBUG any problem stops the app so a bad content
    /// change is noticed immediately; in release the valid items are used and the problem is logged
    /// (counts, and item IDs marked private).
    private func loadBundledCatalog() -> Catalog {
        let result = BundleContentLoader().load(bundle: .main)
        if result.hasProblems {
            ContentBootstrapReporter().report(result)
            #if DEBUG
            assertionFailure("Bundled content has problems; see the 'content' log category.")
            #endif
        }
        return result.catalog
    }
}
