import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// What survives closing and reopening the app, and what Reset clears (DECISIONS 045). These used to be
/// checked by terminating and relaunching the app in a UI test; here the "relaunch" is a second store
/// object over the same file, which is all a relaunch does to the stored data.
///
/// Real `FileProgressStore` and `FileProfileStore` over a scratch folder, the fake `PreviewCatalog`, and the
/// real view models for Home, Progress and Settings.
@MainActor
struct ProgressSurvivesAndResetsFlowTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    /// Runs `body` with a fresh scratch folder and removes it afterwards, pass or fail.
    private func withScratchFolder(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zz-BLTFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await body(folder)
    }

    private func dependencies(store: some ProgressStore) -> AppDependencies {
        let fixedNow = now
        return AppDependencies(
            catalog: PreviewCatalog.catalog,
            language: .tamil,
            store: store,
            scheduler: SM2Scheduler(),
            now: { fixedNow }
        )
    }

    /// Answers one fixture item correctly through a real session and ends it, as the End control does.
    private func answerOneItemAndEnd(store: some ProgressStore) async throws {
        let model = SessionViewModel(
            scenario: PreviewCatalog.scenario,
            dependencies: dependencies(store: store),
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

    private func homePercent(store: some ProgressStore) async throws -> Int {
        let home = HomeViewModel(dependencies: dependencies(store: store))
        await home.load()
        return try #require(home.scenarios.first).completionPercent
    }

    private func attemptCount(store: some ProgressStore) async throws -> Int {
        let progress = ProgressViewModel(dependencies: dependencies(store: store))
        await progress.load()
        return try #require(progress.summary).attemptCount
    }

    // MARK: Surviving a relaunch

    @Test func theCompletionFigureAndAttemptCountSurviveReopeningTheFile() async throws {
        try await withScratchFolder { folder in
            let file = folder.appendingPathComponent("progress.json")
            try await answerOneItemAndEnd(store: FileProgressStore(fileURL: file))

            let reopened = FileProgressStore(fileURL: file)

            #expect(try await homePercent(store: reopened) == 50)
            #expect(try await attemptCount(store: reopened) == 1)
        }
    }

    @Test func aSavedNameIsReadBackAsTheHomeGreetingAfterReopening() async throws {
        try await withScratchFolder { folder in
            let file = folder.appendingPathComponent("profile.json")
            let validName = try ProfileNameValidator.validate("  ZzPerson ").get()
            try await FileProfileStore(fileURL: file).save(UserProfile(name: validName))

            let loaded = try await FileProfileStore(fileURL: file).load()
            let reopened = try #require(loaded)

            #expect(HomeViewModel.greeting(forName: reopened.name) == "Hi ZzPerson")
        }
    }

    @Test func aFreshInstallHasNoProfileSoOnboardingShows() async throws {
        try await withScratchFolder { folder in
            let store = FileProfileStore(fileURL: folder.appendingPathComponent("profile.json"))

            let loaded = try await store.load()
            #expect(loaded == nil)
        }
    }

    // MARK: Reset

    @Test func erasingTheFileLeavesAReopenedStoreAtZeroPercentAndZeroAttempts() async throws {
        try await withScratchFolder { folder in
            let file = folder.appendingPathComponent("progress.json")
            let store = FileProgressStore(fileURL: file)
            try await answerOneItemAndEnd(store: store)
            #expect(try await homePercent(store: store) == 50)

            try await store.eraseAll()
            let reopened = FileProgressStore(fileURL: file)

            #expect(try await homePercent(store: reopened) == 0)
            #expect(try await attemptCount(store: reopened) == 0)
        }
    }

    @Test func aConfirmedResetClearsProgressButKeepsTheName() async throws {
        try await withScratchFolder { folder in
            let progressStore = FileProgressStore(fileURL: folder.appendingPathComponent("progress.json"))
            let profileStore = FileProfileStore(fileURL: folder.appendingPathComponent("profile.json"))
            try await profileStore.save(UserProfile(name: "ZzTest"))
            try await answerOneItemAndEnd(store: progressStore)
            let settings = SettingsViewModel(
                dependencies: dependencies(store: progressStore),
                profileStore: profileStore,
                profileName: "ZzTest"
            )

            settings.requestReset()
            #expect(settings.isConfirmingReset)
            await settings.confirmReset()

            #expect(settings.resetOutcome == .succeeded)
            #expect(settings.profileName == "ZzTest")
            let kept = try await profileStore.load()
            #expect(kept == UserProfile(name: "ZzTest"))
            #expect(try await homePercent(store: progressStore) == 0)
            #expect(try await attemptCount(store: progressStore) == 0)
        }
    }

    @Test func aCancelledResetChangesNothing() async throws {
        try await withScratchFolder { folder in
            let progressStore = FileProgressStore(fileURL: folder.appendingPathComponent("progress.json"))
            let profileStore = FileProfileStore(fileURL: folder.appendingPathComponent("profile.json"))
            try await answerOneItemAndEnd(store: progressStore)
            let settings = SettingsViewModel(
                dependencies: dependencies(store: progressStore),
                profileStore: profileStore,
                profileName: "ZzTest"
            )

            settings.requestReset()
            settings.cancelReset()

            #expect(!settings.isConfirmingReset)
            #expect(settings.resetOutcome == nil)
            #expect(try await homePercent(store: progressStore) == 50)
            #expect(try await attemptCount(store: progressStore) == 1)
        }
    }
}
