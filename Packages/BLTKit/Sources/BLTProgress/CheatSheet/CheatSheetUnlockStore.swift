/// Persistence for the topics of one course whose cheat sheet has been unlocked. A topic unlocks the first
/// time it is complete and stays unlocked. One store per course; the app decides which file it is.
public protocol CheatSheetUnlockStore: Sendable {
    /// The topic ids that have ever been completed. Empty when nothing has been recorded yet.
    func load() async throws(CheatSheetUnlockError) -> Set<String>
    /// Records topics as unlocked. Idempotent: ids already recorded are ignored, and when nothing is new
    /// nothing is written.
    func add(_ topicIDs: Set<String>) async throws(CheatSheetUnlockError)
    /// Removes the whole record (Reset progress). Succeeds when there is none.
    func erase() async throws(CheatSheetUnlockError)
}
