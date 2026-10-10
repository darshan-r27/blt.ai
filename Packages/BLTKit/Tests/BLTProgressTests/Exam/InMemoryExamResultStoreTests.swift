import BLTProgress
import Testing

struct InMemoryExamResultStoreTests {
    private typealias Contract = ExamResultStoreContract

    @Test func newStoreLoadsEmpty() async throws {
        try await Contract.checkNewStoreLoadsEmpty(InMemoryExamResultStore())
    }

    @Test func appendRoundTrips() async throws {
        try await Contract.checkAppendRoundTrips(InMemoryExamResultStore())
    }

    @Test func attemptsComeBackOldestFirst() async throws {
        try await Contract.checkAttemptsComeBackOldestFirst(InMemoryExamResultStore())
    }

    @Test func keepsOnlyTheLastTwentyAttempts() async throws {
        try await Contract.checkKeepsOnlyTheLastTwentyAttempts(InMemoryExamResultStore())
    }

    @Test func exactlyTwentyAreAllKept() async throws {
        try await Contract.checkExactlyTwentyAreAllKept(InMemoryExamResultStore())
    }

    @Test func bestAttemptIsTheHighestShareAndLatestWinsTies() async throws {
        try await Contract.checkBestAttemptIsTheHighestShareAndLatestWinsTies(InMemoryExamResultStore())
    }

    @Test func hasPassedIsTrueOnceAnyAttemptPassed() async throws {
        try await Contract.checkHasPassedIsTrueOnceAnyAttemptPassed(InMemoryExamResultStore())
    }

    @Test func eraseClearsAndIsIdempotent() async throws {
        try await Contract.checkEraseClearsAndIsIdempotent(InMemoryExamResultStore())
    }

    @Test func appendAfterEraseStartsFresh() async throws {
        try await Contract.checkAppendAfterEraseStartsFresh(InMemoryExamResultStore())
    }

    @Test func initialAttemptsAreTrimmedToTheCap() async throws {
        let attempts = (0..<25).map { Contract.attempt(day: $0) }
        let store = InMemoryExamResultStore(initial: attempts)
        #expect(try await store.load() == Array(attempts.suffix(20)))
    }
}
