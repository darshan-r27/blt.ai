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
///   --uitest-practice=<count>    seed both courses' practice logs with a streak of <count> days ending yesterday
///                                evening (one finished session a day). Also fixes the app's clock to noon today
///                                (it still runs forward in real time), so "today", the 24-hour window and the
///                                deadline never depend on the time the test runs at, midnight included.
///   --uitest-practice-<language>=<count>
///                                the same for one course (`tamil` or `telugu`); wins over --uitest-practice.
///                                Seeding replaces the course's log, so a test needs --uitest-reset too.
///   --uitest-notifications=<status>
///                                what the fake reminder scheduler reports: `authorized` (the default, so no
///                                test meets the permission pre-prompt by accident), `notDetermined` or `denied`.
///                                Nothing in a UI-test launch touches the real notification centre or opens the
///                                real iOS Settings: both are fakes.
///
/// The separate files mean a UI test run can never read or erase a real progress file or a real name. Each
/// language has its own fixture lessons, progress file and imported-lessons folder, as in the shipping app.
struct UITestLaunch {
    static let fixturesArgument = "--uitest-fixtures"
    static let resetArgument = "--uitest-reset"
    static let namePrefix = "--uitest-name="
    static let languagePrefix = "--uitest-language="
    static let practicePrefix = "--uitest-practice="
    static let notificationsPrefix = "--uitest-notifications="
    static let profileFileName = "uitest-profile.json"
    static let practicePreferencesFileName = "uitest-practice-preferences.json"

    /// `--uitest-practice-<language>=`, the per-course form of `practicePrefix`.
    static func practicePrefix(for language: CourseLanguage) -> String {
        "--uitest-practice-\(language.rawValue)="
    }

    /// `uitest-practice-<language>.json`, the fixture's practice log.
    static func practiceLogFileName(for language: CourseLanguage) -> String {
        "uitest-practice-\(language.rawValue).json"
    }

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

        let stores = CourseStores(
            make: { FileProgressStore(fileURL: Self.fileURL(Self.progressFileName(for: $0))) },
            makePractice: { FilePracticeLogStore(fileURL: Self.fileURL(Self.practiceLogFileName(for: $0))) }
        )
        let practicePreferences = FilePracticePreferencesStore(fileURL: Self.fileURL(Self.practicePreferencesFileName))
        let profileStore = FileProfileStore(fileURL: Self.fileURL(Self.profileFileName))
        if wantsReset {
            await resetFiles(stores: stores, profileStore: profileStore, preferences: practicePreferences)
        }
        if let seedName {
            await seed(profileStore, name: seedName, language: seedLanguage)
        }
        for language in CourseLanguage.allCases {
            if let days = practiceDays(for: language) {
                await seedStreak(stores.practiceLog(for: language), days: days)
            }
        }
        return makeComposed(stores: stores, profileStore: profileStore, preferences: practicePreferences)
    }

    private func makeComposed(
        stores: CourseStores,
        profileStore: FileProfileStore,
        preferences: FilePracticePreferencesStore
    ) -> CompositionRoot.Composed {
        let now = clock()
        return CompositionRoot.Composed(
            profileStore: profileStore,
            makeCourse: { language in
                CourseServices(
                    dependencies: AppDependencies(
                        catalog: PreviewCatalog.catalog(for: language),
                        language: language,
                        store: stores.store(for: language),
                        scheduler: SM2Scheduler(),
                        now: now,
                        practiceLog: stores.practiceLog(for: language)
                    ),
                    lessonImporter: Self.importer(for: language)
                )
            },
            practice: PracticeServices(
                preferences: preferences,
                reminders: FakeReminderScheduler(status: reminderStatus),
                logs: { stores.practiceLog(for: $0) },
                openSystemSettings: {}
            )
        )
    }

    /// Erases every file a UI-test launch keeps, both languages, so the test starts from nothing.
    private func resetFiles(
        stores: CourseStores,
        profileStore: FileProfileStore,
        preferences: FilePracticePreferencesStore
    ) async {
        for language in CourseLanguage.allCases {
            await erase(stores.store(for: language))
            await erase(Self.importer(for: language))
            await erase(stores.practiceLog(for: language))
        }
        await erase(profileStore)
        await reset(preferences)
    }

    /// The app's clock: real time, or noon today when the launch seeds practice (see the arguments above).
    private func clock() -> @Sendable () -> Date {
        if hasPracticeSeeding {
            return Self.noonClock()
        }
        return { Date.now }
    }

    private var hasPracticeSeeding: Bool {
        arguments.contains { $0.hasPrefix("--uitest-practice") && $0.contains("=") }
    }

    private var reminderStatus: ReminderAuthorization {
        switch value(after: Self.notificationsPrefix) {
        case "notDetermined": .notDetermined
        case "denied": .denied
        default: .authorized
        }
    }

    /// The days of streak asked for this course: its own argument, else the one for both.
    private func practiceDays(for language: CourseLanguage) -> Int? {
        let text = value(after: Self.practicePrefix(for: language)) ?? value(after: Self.practicePrefix)
        guard let text else { return nil }
        guard let days = Int(text), days >= 0 else {
            assertionFailure("\(Self.practicePrefix) must be a whole number of days.")
            return nil
        }
        return days
    }

    /// Noon today in the learner's time zone, then running forward with real time. A test that seeds a streak
    /// gets the same "now" whatever hour it runs at.
    private static func noonClock() -> @Sendable () -> Date {
        let started = Date.now
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: started) ?? started
        return { noon.addingTimeInterval(Date.now.timeIntervalSince(started)) }
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

    private func erase(_ store: any PracticeLogStore) async {
        do throws(PracticeLogError) {
            try await store.erase()
        } catch {
            Self.logger.error("UI-test practice log could not be erased.")
            assertionFailure("UI-test reset failed; the test would start from a stale streak.")
        }
    }

    /// The reminder choices have no erase: saving the defaults is the same as a fresh install.
    private func reset(_ store: FilePracticePreferencesStore) async {
        do throws(PracticePreferencesError) {
            try await store.save(.standard)
        } catch {
            Self.logger.error("UI-test reminder choices could not be reset.")
            assertionFailure("UI-test reset failed; the test would start from stale reminder choices.")
        }
    }

    /// Replaces the course's log with `days` days of practice, one finished session a day, the latest at 6 pm
    /// yesterday on the UI-test clock (noon today): inside the 24-hour window, and not today, so the first
    /// session a test finishes is a new date and grows the streak.
    private func seedStreak(_ store: any PracticeLogStore, days: Int) async {
        await erase(store)
        let clock = Self.noonClock()
        let latest = clock().addingTimeInterval(-18 * 60 * 60)
        for day in (0..<days).reversed() {
            let finishedAt = latest.addingTimeInterval(-Double(day) * StreakCalculator.window)
            do throws(PracticeLogError) {
                try await store.append(PracticeSession(finishedAt: finishedAt, answered: 10))
            } catch {
                Self.logger.error("UI-test practice log could not be seeded.")
                assertionFailure("UI-test streak could not be seeded.")
                return
            }
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
