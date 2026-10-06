/// A `ProgressStore` that keeps everything in memory. For tests and previews; behaves like
/// `FileProgressStore` minus the failure modes that only a disk can have.
public actor InMemoryProgressStore: ProgressStore {
    private var snapshot: ProgressSnapshot

    public init(initial: ProgressSnapshot = .empty) {
        snapshot = initial
    }

    public func load() async throws(ProgressStoreError) -> ProgressSnapshot {
        snapshot
    }

    public func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {
        snapshot = snapshot.recording(attempt, updating: review)
    }

    public func eraseAll() async throws(ProgressStoreError) {
        snapshot = .empty
    }
}
