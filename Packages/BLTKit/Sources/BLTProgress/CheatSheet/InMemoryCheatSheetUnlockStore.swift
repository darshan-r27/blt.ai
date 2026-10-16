/// A `CheatSheetUnlockStore` that keeps everything in memory. For tests and previews; behaves like
/// `FileCheatSheetUnlockStore` minus the failure modes that only a disk can have.
public actor InMemoryCheatSheetUnlockStore: CheatSheetUnlockStore {
    private var topicIDs: Set<String>

    public init(initial: Set<String> = []) {
        topicIDs = initial
    }

    public func load() async throws(CheatSheetUnlockError) -> Set<String> {
        topicIDs
    }

    public func add(_ topicIDs: Set<String>) async throws(CheatSheetUnlockError) {
        self.topicIDs.formUnion(topicIDs)
    }

    public func erase() async throws(CheatSheetUnlockError) {
        topicIDs = []
    }
}
