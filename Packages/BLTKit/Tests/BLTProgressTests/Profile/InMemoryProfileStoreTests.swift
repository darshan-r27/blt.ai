import BLTProgress
import Testing

struct InMemoryProfileStoreTests {
    private typealias Contract = ProfileStoreContract

    @Test func newStoreLoadsNil() async throws {
        try await Contract.checkNewStoreLoadsNil(InMemoryProfileStore())
    }

    @Test func roundTrip() async throws {
        try await Contract.checkRoundTrip(InMemoryProfileStore())
    }

    @Test func saveStoresExactlyWhatItIsGiven() async throws {
        try await Contract.checkSaveStoresExactlyWhatItIsGiven(InMemoryProfileStore())
    }

    @Test func overwriteReplacesPreviousName() async throws {
        try await Contract.checkOverwriteReplacesPreviousName(InMemoryProfileStore())
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await Contract.checkEraseClearsAndIsIdempotent(InMemoryProfileStore())
    }

    @Test func saveAfterEraseStartsFresh() async throws {
        try await Contract.checkSaveAfterEraseStartsFresh(InMemoryProfileStore())
    }

    @Test func initialProfileIsLoaded() async throws {
        let profile = UserProfile(name: "zz")
        let loaded = try await InMemoryProfileStore(initial: profile).load()
        #expect(loaded == profile)
    }
}
