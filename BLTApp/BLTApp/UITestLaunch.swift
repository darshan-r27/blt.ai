#if DEBUG
import BLTFeatures
import BLTProgress
import Foundation
import os

/// Launch arguments for UI tests, compiled into Debug builds only.
///
///   --uitest-fixtures   run on `PreviewCatalog` (fake content) with a separate progress file
///   --uitest-reset      erase that separate progress file before the app starts
///
/// The separate file means a UI test run can never read or erase real progress.
struct UITestLaunch {
    static let fixturesArgument = "--uitest-fixtures"
    static let resetArgument = "--uitest-reset"
    static let progressFileName = "uitest-progress.json"

    private static let logger = Logger(subsystem: "ai.blt.app", category: "uitest")

    private let arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    /// `nil` when this is not a UI-test launch.
    func makeDependencies() async -> AppDependencies? {
        let wantsFixtures = arguments.contains(Self.fixturesArgument)
        let wantsReset = arguments.contains(Self.resetArgument)
        guard wantsFixtures else {
            // Resetting without fixtures would leave the test on the real catalog, which is a mistake in the test.
            assert(!wantsReset, "\(Self.resetArgument) needs \(Self.fixturesArgument)")
            return nil
        }
        let store = FileProgressStore(fileURL: CompositionRoot.supportFileURL(named: Self.progressFileName))
        if wantsReset {
            await erase(store)
        }
        return AppDependencies(
            catalog: PreviewCatalog.catalog,
            store: store,
            scheduler: SM2Scheduler(),
            now: { Date.now }
        )
    }

    private func erase(_ store: FileProgressStore) async {
        do throws(ProgressStoreError) {
            try await store.eraseAll()
        } catch {
            Self.logger.error("UI-test progress file could not be erased.")
            assertionFailure("UI-test reset failed; the test would start from stale progress.")
        }
    }
}
#endif
