#if DEBUG
import BLTProgress

/// A store whose `load()` always throws, for previewing error states. Erasing succeeds and is a no-op.
struct PreviewFailingStore: ProgressStore {
    let loadError: ProgressStoreError

    func load() async throws(ProgressStoreError) -> ProgressSnapshot {
        throw loadError
    }

    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {}

    func eraseAll() async throws(ProgressStoreError) {}
}
#endif
