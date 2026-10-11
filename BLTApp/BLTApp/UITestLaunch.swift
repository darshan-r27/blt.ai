#if DEBUG
import BLTContentStore
import BLTCore
import BLTFeatures
import BLTProgress
import Foundation
import os

/// Launch arguments for UI tests, compiled into Debug builds only.
///
///   --uitest-fixtures            run on `PreviewCatalog` (fake content) with separate progress and profile files
///   --uitest-reset               erase those separate files (both languages) before the app starts
///   --uitest-name=<Name>         save a profile with this name, so the test starts past the name step
///   --uitest-language=<language> with the name, save this learning language too (`tamil` or `telugu`), so the
///                                test starts on Home. A name alone seeds no language, so a test can reach the
///                                language step.
///
/// The separate files mean a UI test run can never read or erase a real progress file or a real name. Each
/// language has its own fixture lessons, progress file and imported-lessons folder, as in the shipping app.
struct UITestLaunch {
    static let fixturesArgument = "--uitest-fixtures"
    static let resetArgument = "--uitest-reset"
    static let namePrefix = "--uitest-name="
    static let languagePrefix = "--uitest-language="
    static let profileFileName = "uitest-profile.json"

    /// `uitest-progress-<language>.json`, beside the real files but never the same name.
    static func progressFileName(for language: CourseLanguage) -> String {
        "uitest-progress-\(language.rawValue).json"
    }

    /// `uitest-content-<language>`, the fixture's imported-lessons folder.
    static func importedFolderName(for language: CourseLanguage) -> String {
        "uitest-content-\(language.rawValue)"
    }

    private static let logger = Logger(subsystem: "ai.blt.app", category: "uitest")

    private let arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    /// `nil` when this is not a UI-test launch.
    func compose() async -> CompositionRoot.Composed? {
        let wantsFixtures = arguments.contains(Self.fixturesArgument)
        let wantsReset = arguments.contains(Self.resetArgument)
        let seedName = value(after: Self.namePrefix)
        let seedLanguageText = value(after: Self.languagePrefix)
        guard wantsFixtures else {
            // These without fixtures would leave the test on the real catalog and files: a mistake in the test.
            assert(
                !wantsReset && seedName == nil && seedLanguageText == nil,
                "Reset and seeding need \(Self.fixturesArgument)"
            )
            return nil
        }
        let seedLanguage = seedLanguageText.flatMap(CourseLanguage.init(rawValue:))
        assert(seedLanguageText == nil || seedLanguage != nil, "\(Self.languagePrefix) must be tamil or telugu.")
        assert(seedLanguage == nil || seedName != nil, "\(Self.languagePrefix) needs \(Self.namePrefix).")

        let stores = CourseStores { FileProgressStore(fileURL: Self.fileURL(Self.progressFileName(for: $0))) }
        let profileStore = FileProfileStore(fileURL: Self.fileURL(Self.profileFileName))
        if wantsReset {
            for language in CourseLanguage.allCases {
                await erase(stores.store(for: language))
                await erase(Self.importer(for: language))
            }
            await erase(profileStore)
        }
        if let seedName {
            await seed(profileStore, name: seedName, language: seedLanguage)
        }
        return CompositionRoot.Composed(
            profileStore: profileStore,
            makeCourse: { language in
                CourseServices(
                    dependencies: AppDependencies(
                        catalog: PreviewCatalog.catalog(for: language),
                        language: language,
                        store: stores.store(for: language),
                        scheduler: SM2Scheduler(),
                        now: { Date.now }
                    ),
                    lessonImporter: Self.importer(for: language)
                )
            }
        )
    }

    private func value(after prefix: String) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }

    private static func fileURL(_ name: String) -> URL {
        CompositionRoot.supportFileURL(named: name)
    }

    /// A real store over a separate folder with no bundled folder, so Settings shows the Lessons section
    /// without the test ever touching the real imported lessons.
    private static func importer(for language: CourseLanguage) -> ImportedContentStore {
        ImportedContentStore(
            directory: fileURL(importedFolderName(for: language)),
            bundledDirectory: nil,
            language: language
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

    private func erase(_ store: any ProgressStore) async {
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

    /// Saves the validated name, and the language when one was given, exactly as the app itself would.
    private func seed(_ store: FileProfileStore, name: String, language: CourseLanguage?) async {
        guard case .success(let validName) = ProfileNameValidator.validate(name) else {
            Self.logger.error("UI-test name was rejected by the name validator.")
            assertionFailure("\(Self.namePrefix) must be a valid name.")
            return
        }
        do throws(ProfileStoreError) {
            try await store.save(UserProfile(name: validName, learningLanguage: language))
        } catch {
            Self.logger.error("UI-test profile could not be saved.")
            assertionFailure("UI-test name could not be seeded; the test would start on onboarding.")
        }
    }
}
#endif
