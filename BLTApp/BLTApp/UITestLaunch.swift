#if DEBUG
import BLTContentStore
import BLTFeatures
import BLTProgress
import Foundation
import os

/// Launch arguments for UI tests, compiled into Debug builds only.
///
///   --uitest-fixtures     run on `PreviewCatalog` (fake content) with separate progress and profile files
///   --uitest-reset        erase those separate files before the app starts
///   --uitest-name=<Name>  save a profile with this name, so the test starts on Home instead of onboarding
///
/// The separate files mean a UI test run can never read or erase a real progress file or a real name.
struct UITestLaunch {
    static let fixturesArgument = "--uitest-fixtures"
    static let resetArgument = "--uitest-reset"
    static let namePrefix = "--uitest-name="
    static let progressFileName = "uitest-progress.json"
    static let profileFileName = "uitest-profile.json"
    static let importedFolderName = "uitest-content"

    private static let logger = Logger(subsystem: "ai.blt.app", category: "uitest")

    private let arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    /// `nil` when this is not a UI-test launch.
    func compose() async -> CompositionRoot.Composed? {
        let wantsFixtures = arguments.contains(Self.fixturesArgument)
        let wantsReset = arguments.contains(Self.resetArgument)
        let seedName = arguments
            .first { $0.hasPrefix(Self.namePrefix) }
            .map { String($0.dropFirst(Self.namePrefix.count)) }
        guard wantsFixtures else {
            // These without fixtures would leave the test on the real catalog and files: a mistake in the test.
            assert(!wantsReset && seedName == nil, "Reset and seeding a name need \(Self.fixturesArgument)")
            return nil
        }
        let progressStore = FileProgressStore(fileURL: CompositionRoot.supportFileURL(named: Self.progressFileName))
        let profileStore = FileProfileStore(fileURL: CompositionRoot.supportFileURL(named: Self.profileFileName))
        // A real store over a separate folder with no bundled folder, so Settings shows the Lessons section
        // without the test ever touching the real imported lessons.
        let importer = ImportedContentStore(
            directory: CompositionRoot.supportFileURL(named: Self.importedFolderName),
            bundledDirectory: nil
        )
        if wantsReset {
            await erase(progressStore)
            await erase(profileStore)
            await erase(importer)
        }
        if let seedName {
            await seed(profileStore, name: seedName)
        }
        return CompositionRoot.Composed(
            dependencies: AppDependencies(
                catalog: PreviewCatalog.catalog,
                store: progressStore,
                scheduler: SM2Scheduler(),
                now: { Date.now }
            ),
            profileStore: profileStore,
            lessonImporter: importer
        )
    }

    private func erase(_ importer: ImportedContentStore) async {
        do throws(ContentImportFailure) {
            try await importer.removeAll()
        } catch {
            Self.logger.error("UI-test imported lessons could not be removed.")
            assertionFailure("UI-test reset failed; the test would start from stale imported lessons.")
        }
    }

    private func erase(_ store: FileProgressStore) async {
        do throws(ProgressStoreError) {
            try await store.eraseAll()
        } catch {
            Self.logger.error("UI-test progress file could not be erased.")
            assertionFailure("UI-test reset failed; the test would start from stale progress.")
        }
    }

    private func erase(_ store: FileProfileStore) async {
        do throws(ProfileStoreError) {
            try await store.erase()
        } catch {
            Self.logger.error("UI-test profile file could not be erased.")
            assertionFailure("UI-test reset failed; the test would start from a stale profile.")
        }
    }

    /// Saves the validated name, exactly as the app itself would.
    private func seed(_ store: FileProfileStore, name: String) async {
        guard case .success(let validName) = ProfileNameValidator.validate(name) else {
            Self.logger.error("UI-test name was rejected by the name validator.")
            assertionFailure("\(Self.namePrefix) must be a valid name.")
            return
        }
        do throws(ProfileStoreError) {
            try await store.save(UserProfile(name: validName))
        } catch {
            Self.logger.error("UI-test profile could not be saved.")
            assertionFailure("UI-test name could not be seeded; the test would start on onboarding.")
        }
    }
}
#endif
