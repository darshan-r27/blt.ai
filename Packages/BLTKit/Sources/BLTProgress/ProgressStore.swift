public protocol ProgressStore: Sendable {
    func load() async throws(ProgressStoreError) -> ProgressSnapshot
    /// Precondition: `review.itemID == attempt.itemID`.
    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError)
    func eraseAll() async throws(ProgressStoreError)
}
