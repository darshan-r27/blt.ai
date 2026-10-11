import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// Each language keeps its own progress, and Reset clears only the language being learned (DECISIONS 043).
/// These rules used to need a second language to be switched in a running app; here each language has its own
/// real `FileProgressStore` at the path layout the app uses (`courses/<language>/progress.json`), the fake
/// fixture lessons of that language, and the real Home and Settings view models.
@MainActor
struct TwoCoursesStayApartTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func withScratchFolder(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zz-BLTCoursesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await body(folder)
    }

    private func store(_ language: CourseLanguage, in folder: URL) -> FileProgressStore {
        FileProgressStore(
            fileURL: folder
                .appendingPathComponent("courses", isDirectory: true)
                .appendingPathComponent(language.rawValue, isDirectory: true)
                .appendingPathComponent("progress.json")
        )
    }

    private func dependencies(_ language: CourseLanguage, store: some ProgressStore) -> AppDependencies {
        let fixedNow = now
        return AppDependencies(
            catalog: PreviewCatalog.catalog(for: language),
            language: language,
            store: store,
            scheduler: SM2Scheduler(),
            now: { fixedNow }
        )
    }

    private func scenario(_ language: CourseLanguage) throws -> Scenario {
        try #require(PreviewCatalog.catalog(for: language).scenarios.first)
    }

    /// Answers the first question of the course's fixture lesson correctly and ends the session.
    private func answerOneItem(_ language: CourseLanguage, store: some ProgressStore) async throws {
        let model = SessionViewModel(
            scenario: try scenario(language),
            dependencies: dependencies(language, store: store),
            random: .seeded(11)
        )
        await model.start()
        guard case .session(.asking(let question)) = model.screen,
              let canonical = question.options.first(where: { $0.kind == .canonical }) else {
            Issue.record("expected a question with a canonical option")
            return
        }
        model.choose(canonical.id)
        await model.endSession()
    }

    private func homePercent(_ language: CourseLanguage, store: some ProgressStore) async throws -> Int {
        let home = HomeViewModel(dependencies: dependencies(language, store: store))
        await home.load()
        return try #require(home.scenarios.first).completionPercent
    }

    @Test func answeringInOneLanguageLeavesTheOtherLanguageUntouchedAfterAReopen() async throws {
        try await withScratchFolder { folder in
            try await answerOneItem(.tamil, store: store(.tamil, in: folder))

            // "Reopen" with new store objects over the same files: the other language still shows nothing.
            #expect(try await homePercent(.tamil, store: store(.tamil, in: folder)) == 50)
            #expect(try await homePercent(.telugu, store: store(.telugu, in: folder)) == 0)

            // Switching back finds the first language exactly as it was left.
            #expect(try await homePercent(.tamil, store: store(.tamil, in: folder)) == 50)
        }
    }

    @Test func eachLanguageShowsOnlyItsOwnLessonsAndTheirLanguage() throws {
        for language in CourseLanguage.allCases {
            let lessons = PreviewCatalog.catalog(for: language).scenarios
            #expect(lessons.count == 1)
            #expect(lessons.allSatisfy { $0.language == language })
        }
        let tamilIDs = PreviewCatalog.catalog(for: .tamil).allItemIDs
        let teluguIDs = PreviewCatalog.catalog(for: .telugu).allItemIDs
        #expect(tamilIDs.isDisjoint(with: teluguIDs))
    }

    @Test func resettingTeluguKeepsTamilProgressAndTheConfirmationNamesTelugu() async throws {
        try await withScratchFolder { folder in
            try await answerOneItem(.tamil, store: store(.tamil, in: folder))
            try await answerOneItem(.telugu, store: store(.telugu, in: folder))

            let settings = SettingsViewModel(
                dependencies: dependencies(.telugu, store: store(.telugu, in: folder)),
                profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .telugu)),
                profileName: "zz Sample",
                learningLanguage: .telugu
            )
            settings.requestReset()
            #expect(settings.isConfirmingReset)
            #expect(settings.resetTitle.contains("Telugu"))
            #expect(settings.resetMessage.contains("Telugu"))
            #expect(!settings.resetTitle.contains("Tamil"))
            await settings.confirmReset()

            #expect(try await homePercent(.telugu, store: store(.telugu, in: folder)) == 0)
            #expect(try await homePercent(.tamil, store: store(.tamil, in: folder)) == 50)
        }
    }

    @Test func resettingTamilKeepsTeluguProgress() async throws {
        try await withScratchFolder { folder in
            try await answerOneItem(.tamil, store: store(.tamil, in: folder))
            try await answerOneItem(.telugu, store: store(.telugu, in: folder))

            let settings = SettingsViewModel(
                dependencies: dependencies(.tamil, store: store(.tamil, in: folder)),
                profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .tamil)),
                profileName: "zz Sample",
                learningLanguage: .tamil
            )
            settings.requestReset()
            #expect(settings.resetTitle.contains("Tamil"))
            await settings.confirmReset()

            #expect(try await homePercent(.tamil, store: store(.tamil, in: folder)) == 0)
            #expect(try await homePercent(.telugu, store: store(.telugu, in: folder)) == 50)
        }
    }

    @Test func switchingLanguageInSettingsKeepsTheNameAndReportsTheNewProfile() async throws {
        let profileStore = InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let report = ProfileReport()
        let settings = SettingsViewModel(
            dependencies: dependencies(.tamil, store: InMemoryProgressStore()),
            profileStore: profileStore,
            profileName: "zz Sample",
            learningLanguage: .tamil,
            onDidChangeLanguage: { report.profiles.append($0) }
        )
        settings.chooseLanguage(.telugu)
        await settings.confirmLanguageChange()

        #expect(report.profiles == [UserProfile(name: "zz Sample", learningLanguage: .telugu)])
        #expect(try await profileStore.load() == UserProfile(name: "zz Sample", learningLanguage: .telugu))
    }

    @Test func theGateShowsHomeForTheNewLanguageAfterASwitch() async throws {
        let store = InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample", learningLanguage: .tamil)))

        gate.profileDidChange(UserProfile(name: "zz Sample", learningLanguage: .telugu))

        #expect(gate.state == .ready(UserProfile(name: "zz Sample", learningLanguage: .telugu)))
    }

    @Test func aProfileWithNoLanguageIsAskedNeverAssumed() async {
        let gate = ProfileGateViewModel(store: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")))
        await gate.load()
        #expect(gate.state == .needsLanguage(UserProfile(name: "zz Sample")))
    }
}

@MainActor
private final class ProfileReport {
    var profiles: [UserProfile] = []
}
