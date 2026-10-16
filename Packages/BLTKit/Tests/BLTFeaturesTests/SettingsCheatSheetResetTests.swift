import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// Reset progress in Settings (the path a learner uses) clears the course's cheat sheet unlocks (DECISIONS 048).
@MainActor
struct SettingsCheatSheetResetTests {
    private func settings(unlocks: any CheatSheetUnlockStore) -> SettingsViewModel {
        SettingsViewModel(
            dependencies: SettingsPracticeSupport.dependencies(cheatSheetUnlocks: unlocks),
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
            profileName: "zz Sample",
            learningLanguage: .tamil
        )
    }

    @Test func resetErasesTheCheatSheetUnlocks() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore(initial: ["zz-s"])
        let model = settings(unlocks: unlocks)

        await model.confirmReset()

        #expect(model.resetOutcome == .succeeded)
        let remaining = try await unlocks.load()
        #expect(remaining.isEmpty)
    }

    @Test func resetReportsAFailureToEraseTheCheatSheetUnlocks() async {
        let model = settings(unlocks: FailingEraseUnlockStore())

        await model.confirmReset()

        #expect(model.resetOutcome == .failed(.eraseFailed))
    }
}

private struct FailingEraseUnlockStore: CheatSheetUnlockStore {
    func load() async throws(CheatSheetUnlockError) -> Set<String> { [] }
    func add(_ topicIDs: Set<String>) async throws(CheatSheetUnlockError) {}
    func erase() async throws(CheatSheetUnlockError) { throw .eraseFailed }
}
