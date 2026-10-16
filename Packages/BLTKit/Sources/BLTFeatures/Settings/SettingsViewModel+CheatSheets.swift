import BLTProgress

extension SettingsViewModel {
    /// The cheat sheet unlocks belong to the same course (DECISIONS 048), so Reset clears them too: a sheet belongs
    /// to a topic the learner has finished, and after a reset none is. `false` on failure.
    func eraseCheatSheetUnlocks() async -> Bool {
        do throws(CheatSheetUnlockError) {
            try await cheatSheetUnlocks.erase()
            return true
        } catch {
            return false
        }
    }
}
