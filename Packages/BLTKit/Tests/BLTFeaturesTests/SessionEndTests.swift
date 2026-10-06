import BLTCatalog
import BLTCore
import BLTFeatures
import BLTProgress
import BLTSession
import Foundation
import Testing

/// Counts how many times the host's Done closure ran.
@MainActor
private final class DoneCounter {
    private(set) var calls = 0
    func increment() { calls += 1 }
}

/// A store whose `record` suspends until `release()` is called, to model a slow disk write.
private actor GatedProgressStore: ProgressStore {
    private let inner = InMemoryProgressStore()
    private var waiter: CheckedContinuation<Void, Never>?
    private var isReleased = false
    private(set) var recordStarted = false

    func load() async throws(ProgressStoreError) -> ProgressSnapshot {
        try await inner.load()
    }

    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {
        recordStarted = true
        if !isReleased {
            await withCheckedContinuation { waiter = $0 }
        }
        try await inner.record(attempt, updating: review)
    }

    func eraseAll() async throws(ProgressStoreError) {
        try await inner.eraseAll()
    }

    func release() {
        isReleased = true
        waiter?.resume()
        waiter = nil
    }
}

@MainActor
struct SessionEndTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func makeModel(store: some ProgressStore, done: DoneCounter) -> SessionViewModel {
        let fixedNow = now
        let model = SessionViewModel(
            scenario: PreviewCatalog.scenario,
            dependencies: AppDependencies(
                catalog: PreviewCatalog.catalog,
                store: store,
                scheduler: SM2Scheduler(),
                now: { fixedNow }
            ),
            random: .seeded(42)
        )
        model.setDoneHandler { done.increment() }
        return model
    }

    private func asking(_ model: SessionViewModel) throws -> Question {
        guard case .session(.asking(let question)) = model.screen else { throw EndTestError.notAsking }
        return question
    }

    private func canonicalID(_ question: Question) throws -> Int {
        try #require(question.options.first { $0.kind == .canonical }).id
    }

    // MARK: Ending

    @Test func endingMidQuestionWritesNothingForTheUnansweredItem() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        _ = try asking(model)

        await model.endSession()

        let snapshot = try await store.load()
        #expect(snapshot.attempts.isEmpty)
        #expect(snapshot.reviews.isEmpty)
        #expect(done.calls == 1)
    }

    @Test func endingFromFeedbackKeepsTheAnsweredItem() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        let question = try asking(model)
        model.choose(try canonicalID(question))

        await model.endSession()

        let snapshot = try await store.load()
        #expect(snapshot.attempts == [AttemptRecord(itemID: question.item.id, outcome: .correct, date: now)])
        #expect(snapshot.reviews[question.item.id]?.lastOutcome == .correct)
        #expect(done.calls == 1)
    }

    @Test func endingMidSessionKeepsEarlierAnswersAndNothingForTheCurrentQuestion() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        let first = try asking(model)
        model.choose(try canonicalID(first))
        model.advance()
        let second = try asking(model)
        #expect(second.item.id != first.item.id)

        await model.endSession()

        let snapshot = try await store.load()
        #expect(snapshot.attempts.map(\.itemID) == [first.item.id])
        #expect(snapshot.reviews[second.item.id] == nil)
    }

    @Test func endSessionWaitsForASlowPendingSaveBeforeCallingDone() async throws {
        let store = GatedProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        let question = try asking(model)
        model.choose(try canonicalID(question))

        let ending = Task { await model.endSession() }
        while await !store.recordStarted {
            await Task.yield()
        }
        for _ in 0..<20 {
            await Task.yield()
        }
        // The write is still suspended, so the session must not have been handed back yet.
        #expect(done.calls == 0)

        await store.release()
        await ending.value

        #expect(done.calls == 1)
        let snapshot = try await store.load()
        #expect(snapshot.attempts.map(\.itemID) == [question.item.id])
    }

    @Test func repeatedEndSessionCallsInvokeDoneExactlyOnce() async throws {
        let done = DoneCounter()
        let model = makeModel(store: InMemoryProgressStore(), done: done)
        await model.start()
        model.choose(try canonicalID(try asking(model)))

        async let first: Void = model.endSession()
        async let second: Void = model.endSession()
        _ = await (first, second)
        await model.endSession()

        #expect(done.calls == 1)
        #expect(model.hasEnded)
    }

    @Test func answeringAfterEndingIsIgnoredAndWritesNothing() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        let question = try asking(model)
        let before = model.screen

        await model.endSession()
        model.choose(try canonicalID(question))
        await model.waitForPendingSaves()

        #expect(model.screen == before)
        #expect(try await store.load().attempts.isEmpty)
    }

    @Test func advancingAfterEndingFromFeedbackIsIgnored() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        model.choose(try canonicalID(try asking(model)))
        let before = model.screen

        await model.endSession()
        model.advance()

        #expect(model.screen == before)
        #expect(try await store.load().attempts.count == 1)
    }

    // MARK: Keep going

    @Test func keepingGoingLeavesTheSessionRunningAndWritesNothing() async throws {
        let store = InMemoryProgressStore()
        let done = DoneCounter()
        let model = makeModel(store: store, done: done)
        await model.start()
        let question = try asking(model)

        // "Keep going" is a no-op in the view: endSession is never called.
        #expect(done.calls == 0)
        #expect(!model.hasEnded)
        #expect(try await store.load().attempts.isEmpty)

        model.choose(try canonicalID(question))
        await model.waitForPendingSaves()
        #expect(try await store.load().attempts.count == 1)
        #expect(done.calls == 0)
    }
}

private enum EndTestError: Error {
    case notAsking
}
