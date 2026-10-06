import BLTProgress
import Testing

struct InMemoryProgressStoreTests {
    @Test func newStoreLoadsEmpty() async throws {
        try await ProgressStoreContract.checkNewStoreLoadsEmpty(InMemoryProgressStore())
    }

    @Test func roundTrip() async throws {
        try await ProgressStoreContract.checkRoundTrip(InMemoryProgressStore())
    }

    @Test func replacingReviewKeepsOneEntryPerItem() async throws {
        try await ProgressStoreContract.checkReplacingReviewKeepsOneEntryPerItem(InMemoryProgressStore())
    }

    @Test func concurrentRecordsLoseNothing() async throws {
        try await ProgressStoreContract.checkConcurrentRecordsLoseNothing(InMemoryProgressStore())
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await ProgressStoreContract.checkEraseClearsAndIsIdempotent(InMemoryProgressStore())
    }

    @Test func recordAfterEraseStartsFresh() async throws {
        try await ProgressStoreContract.checkRecordAfterEraseStartsFresh(InMemoryProgressStore())
    }

    @Test func initialSnapshotIsReturned() async throws {
        let review = ProgressStoreContract.review("zz-a")
        let initial = ProgressSnapshot(
            reviews: [review.itemID: review],
            attempts: [ProgressStoreContract.attempt("zz-a")]
        )
        let store = InMemoryProgressStore(initial: initial)
        let snapshot = try await store.load()
        #expect(snapshot == initial)
    }
}
