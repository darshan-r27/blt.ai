import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

@testable import BLTFeatures

/// Shared fakes and builders for the Daily practice settings tests. Fake data only.
enum SettingsPracticeSupport {
    /// Counts how often the settings owner was told about a change.
    actor ChangeCounter {
        private(set) var calls = 0
        func record() { calls += 1 }
    }

    /// A preferences store with controllable failures.
    actor StubPreferencesStore: PracticePreferencesStore {
        private var stored: PracticePreferences
        private let loadError: PracticePreferencesError?
        private let saveError: PracticePreferencesError?
        private(set) var saveCount = 0

        init(
            initial: PracticePreferences = .standard,
            loadError: PracticePreferencesError? = nil,
            saveError: PracticePreferencesError? = nil
        ) {
            stored = initial
            self.loadError = loadError
            self.saveError = saveError
        }

        func load() async throws(PracticePreferencesError) -> PracticePreferences {
            if let loadError { throw loadError }
            return stored
        }

        func save(_ preferences: PracticePreferences) async throws(PracticePreferencesError) {
            saveCount += 1
            if let saveError { throw saveError }
            stored = preferences
        }
    }

    /// A practice log whose erase can fail.
    actor StubPracticeLogStore: PracticeLogStore {
        private var log: PracticeLog
        private let eraseError: PracticeLogError?
        private(set) var eraseCount = 0

        init(log: PracticeLog = .empty, eraseError: PracticeLogError? = nil) {
            self.log = log
            self.eraseError = eraseError
        }

        func load() async throws(PracticeLogError) -> PracticeLog { log }

        func append(_ session: PracticeSession) async throws(PracticeLogError) {
            log = log.appending(session)
        }

        func erase() async throws(PracticeLogError) {
            eraseCount += 1
            if let eraseError { throw eraseError }
            log = .empty
        }
    }

    static func oneSession() -> PracticeLog {
        PracticeLog(sessions: [PracticeSession(finishedAt: Date(timeIntervalSince1970: 1_000_000), answered: 10)])
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    static func dependencies() -> AppDependencies {
        let item = Item(
            id: ItemID(rawValue: "zz-s1"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz prompt",
            register: .neutral,
            addressee: .any,
            canonical: "zz canonical",
            acceptedAnswers: ["zz canonical", "zz alt a", "zz alt b"],
            registerVariant: nil,
            distractors: ["zz wrong a", "zz wrong b", "zz wrong c"],
            tokens: [Token(word: "zz", english: "zz gloss")],
            note: nil,
            reviewStatus: .unreviewed
        )
        let scenario = Scenario(
            id: ScenarioID(rawValue: "zz-s"),
            title: "zz S",
            subtitle: "zz sub",
            romanisationNote: nil,
            items: [item],
            language: .tamil
        )
        return AppDependencies(
            catalog: Catalog(scenarios: [scenario], issues: []),
            language: .tamil,
            store: InMemoryProgressStore(initial: .empty),
            scheduler: SM2Scheduler(),
            now: { Date(timeIntervalSince1970: 1_000_000) }
        )
    }

    @MainActor
    static func settings(
        preferences: any PracticePreferencesStore = InMemoryPracticePreferencesStore(),
        practiceLog: any PracticeLogStore = InMemoryPracticeLogStore(),
        reminders: any ReminderScheduling = FakeReminderScheduler(),
        onChanged: @escaping @Sendable () async -> Void = {},
        openSettings: @escaping @MainActor () -> Void = {}
    ) -> SettingsViewModel {
        SettingsViewModel(
            dependencies: dependencies(),
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
            profileName: "zz Sample",
            learningLanguage: .tamil,
            practicePreferences: preferences,
            practiceLog: practiceLog,
            reminders: reminders,
            calendar: utcCalendar,
            onPracticeSettingsChanged: onChanged,
            openSystemSettings: openSettings
        )
    }
}
