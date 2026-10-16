#if DEBUG
import BLTCore
import BLTProgress
import os

/// The cheat sheet part of a UI-test launch (`--uitest-cheatsheets=<ids>`, see `UITestLaunch`). A separate file
/// only so the launch type stays within the lint limit for a type's length.
extension UITestLaunch {
    /// The topic ids to mark complete for this course: its own argument, else the one for both.
    func cheatSheetIDs(for language: CourseLanguage) -> Set<String>? {
        let text = value(after: Self.cheatSheetsPrefix(for: language)) ?? value(after: Self.cheatSheetsPrefix)
        guard let text else { return nil }
        return Set(text.split(separator: ",").map(String.init))
    }

    func erase(_ store: any CheatSheetUnlockStore) async {
        do throws(CheatSheetUnlockError) {
            try await store.erase()
        } catch {
            Self.logger.error("UI-test cheat sheet record could not be erased.")
            assertionFailure("UI-test reset failed; the test would start with stale cheat sheet unlocks.")
        }
    }

    /// Replaces the course's cheat sheet record with `ids`, so those topics show their button from the first load.
    func seedCheatSheets(_ store: any CheatSheetUnlockStore, ids: Set<String>) async {
        await erase(store)
        do throws(CheatSheetUnlockError) {
            try await store.add(ids)
        } catch {
            Self.logger.error("UI-test cheat sheet record could not be seeded.")
            assertionFailure("UI-test cheat sheet unlocks could not be seeded.")
        }
    }
}
#endif
