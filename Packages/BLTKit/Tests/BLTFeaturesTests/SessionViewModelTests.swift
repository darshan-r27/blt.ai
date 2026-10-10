import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

/// A store whose `record` always fails, to prove the session surfaces the failure and carries on.
struct FailingRecordStore: ProgressStore {
    let initial: ProgressSnapshot

    func load() async throws(ProgressStoreError) -> ProgressSnapshot { initial }

    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {
        throw .writeFailed
    }

    func eraseAll() async throws(ProgressStoreError) {}
}

/// A store whose `load` always fails.
struct FailingLoadStore: ProgressStore {
    func load() async throws(ProgressStoreError) -> ProgressSnapshot { throw .corrupt }
    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {}
    func eraseAll() async throws(ProgressStoreError) {}
}

@MainActor
struct SessionViewModelTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func dependencies(store: some ProgressStore) -> AppDependencies {
        let fixedNow = now
        return AppDependencies(
            catalog: PreviewCatalog.catalog,
            store: store,
            scheduler: SM2Scheduler(),
            now: { fixedNow }
        )
    }

    private func makeModel(
        store: some ProgressStore,
        scenario: Scenario = PreviewCatalog.scenario
    ) -> SessionViewModel {
        SessionViewModel(
            scenario: scenario,
            dependencies: dependencies(store: store),
            random: .seeded(42)
        )
    }

    private func asking(_ model: SessionViewModel) throws -> Question {
        guard case .session(.asking(let question)) = model.screen else { throw ScreenError.notAsking }
        return question
    }

    private func optionID(_ question: Question, _ kind: AnswerOption.Kind) throws -> Int {
        try #require(question.options.first { $0.kind == kind }).id
    }

    private func isFeedback(_ model: SessionViewModel) -> Bool {
        if case .session(.feedback) = model.screen { return true }
        return false
    }

    private func isFinished(_ model: SessionViewModel) -> Bool {
        if case .session(.finished) = model.screen { return true }
        return false
    }

    private func review(for itemID: ItemID, outcome: Outcome) -> ReviewState {
        SM2Scheduler().review(nil, itemID: itemID, outcome: outcome, at: now)
    }

    // MARK: Outcomes and persistence

    @Test(arguments: [
        (AnswerOption.Kind.canonical, Outcome.correct),
        (AnswerOption.Kind.registerVariant, Outcome.wrongRegister),
        (AnswerOption.Kind.distractor, Outcome.wrong)
    ])
    func choosingAnOptionStoresOutcomeAndReviewState(kind: AnswerOption.Kind, outcome: Outcome) async throws {
        let store = InMemoryProgressStore()
        // One item (the one with a register variant), so the random order cannot change what is asked.
        let single = Scenario(
            id: PreviewCatalog.scenarioID,
            title: "zz",
            subtitle: "zz",
            romanisationNote: nil,
            items: [PreviewCatalog.respectfulItem],
            language: .tamil
        )
        let model = makeModel(store: store, scenario: single)
        await model.start()

        let question = try asking(model)
        model.choose(try optionID(question, kind))
        await model.waitForPendingSaves()

        let snapshot = try await store.load()
        #expect(snapshot.attempts == [AttemptRecord(itemID: question.item.id, outcome: outcome, date: now)])
        #expect(snapshot.reviews[question.item.id] == review(for: question.item.id, outcome: outcome))
        #expect(!model.saveFailed)
    }

    @Test func previousReviewStateFromTheLoadedSnapshotFeedsTheScheduler() async throws {
        let itemID = PreviewCatalog.respectfulItem.id
        let earlier = now.addingTimeInterval(-86_400 * 3)
        let previous = SM2Scheduler().review(nil, itemID: itemID, outcome: .correct, at: earlier)
        let initial = ProgressSnapshot(reviews: [itemID: previous], attempts: [])
        let store = InMemoryProgressStore(initial: initial)
        let model = makeModel(store: store)
        await model.start()

        // The session order is random, so reach the previously seen item rather than assume it is first.
        while case .session(.asking(let other)) = model.screen, other.item.id != itemID {
            model.choose(try optionID(other, .canonical))
            model.advance()
        }
        let question = try asking(model)
        #expect(question.item.id == itemID)
        model.choose(try optionID(question, .canonical))
        await model.waitForPendingSaves()

        let stored = try #require(try await store.load().reviews[itemID])
        #expect(stored == SM2Scheduler().review(previous, itemID: itemID, outcome: .correct, at: now))
    }

    @Test func aRequeuedPresentationWritesNothing() async throws {
        let store = InMemoryProgressStore()
        let model = makeModel(store: store)
        await model.start()

        // First item: wrong. It is requeued behind the second item.
        let first = try asking(model)
        model.choose(try optionID(first, .distractor))
        model.advance()
        // Second item: correct.
        let second = try asking(model)
        #expect(second.item.id != first.item.id)
        model.choose(try optionID(second, .canonical))
        model.advance()
        // First item again, answered correctly this time.
        let again = try asking(model)
        #expect(again.item.id == first.item.id)
        model.choose(try optionID(again, .canonical))
        model.advance()
        await model.waitForPendingSaves()

        #expect(isFinished(model))
        let snapshot = try await store.load()
        #expect(snapshot.attempts.count == 2)
        #expect(snapshot.reviews[first.item.id]?.lastOutcome == .wrong)
        #expect(snapshot.reviews[second.item.id]?.lastOutcome == .correct)
    }

    @Test func finishedSummaryCountsFirstAttempts() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        await model.start()
        // The order is random: answer the item with a register variant that way, the other correctly.
        for _ in 0..<2 {
            let question = try asking(model)
            let kind: AnswerOption.Kind = question.item.id == PreviewCatalog.respectfulItem.id
                ? .registerVariant
                : .canonical
            model.choose(try optionID(question, kind))
            model.advance()
        }

        guard case .session(.finished(let result)) = model.screen else {
            Issue.record("expected the finished screen")
            return
        }
        #expect(result == SessionResult(correctCount: 1, wrongRegisterCount: 1, wrongCount: 0))
    }

    @Test func progressCountsEachItemOnce() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        await model.start()
        #expect(model.plannedCount == 2)
        #expect(model.currentPosition == 1)
        model.choose(try optionID(try asking(model), .distractor))
        model.advance()
        #expect(model.currentPosition == 2)
        model.choose(try optionID(try asking(model), .canonical))
        model.advance()
        // The requeued first item keeps its original number.
        #expect(model.currentPosition == 1)
    }

    @Test func aWrongItemStopsReturningAfterItsSecondRequeue() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        await model.start()
        let itemID = try asking(model).item.id
        for expectedReturn in [true, true, false] {
            model.choose(try optionID(try asking(model), .distractor))
            #expect(model.currentItemWillReturn == expectedReturn)
            model.advance()
            while case .session(.asking(let other)) = model.screen, other.item.id != itemID {
                model.choose(try optionID(other, .canonical))
                model.advance()
            }
        }
    }

    // MARK: Failure handling

    @Test func aFailingStoreSurfacesSaveFailedAndTheSessionContinues() async throws {
        let model = makeModel(store: FailingRecordStore(initial: .empty))
        await model.start()
        #expect(!model.saveFailed)

        model.choose(try optionID(try asking(model), .canonical))
        await model.waitForPendingSaves()
        #expect(model.saveFailed)
        #expect(isFeedback(model))

        model.advance()
        model.choose(try optionID(try asking(model), .canonical))
        model.advance()
        await model.waitForPendingSaves()
        #expect(isFinished(model))
        #expect(model.saveFailed)
    }

    @Test func aFailingLoadShowsAnErrorInsteadOfStartingOnAnEmptyGuess() async {
        let model = makeModel(store: FailingLoadStore())
        await model.start()
        #expect(model.screen == .loadFailed)
    }

    // MARK: Planning

    @Test func aFreshScenarioStartsAsking() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        #expect(model.screen == .loading)
        await model.start()
        _ = try asking(model)
    }

    @Test func differentSeedsStartWithDifferentQuestions() async throws {
        let scenario = bigScenario(count: 20)
        var firstItems = Set<String>()
        for seed in UInt64(1)...UInt64(10) {
            let order = try await askedOrder(seed: seed, scenario: scenario)
            #expect(order.count == 10)
            firstItems.insert(try #require(order.first))
        }
        #expect(firstItems.count > 1)
    }

    @Test func theSameSeedReproducesTheSameSessionOrder() async throws {
        let scenario = bigScenario(count: 20)
        let first = try await askedOrder(seed: 7, scenario: scenario)
        let second = try await askedOrder(seed: 7, scenario: scenario)
        let other = try await askedOrder(seed: 8, scenario: scenario)
        #expect(first == second)
        #expect(first != other)
    }

    @Test func anEmptyScenarioShowsTheEmptyState() async {
        let empty = Scenario(
            id: ScenarioID(rawValue: "zz-empty"),
            title: "zz empty",
            subtitle: "zz",
            romanisationNote: nil,
            items: [],
            language: .tamil
        )
        let model = makeModel(store: InMemoryProgressStore(), scenario: empty)
        await model.start()
        #expect(model.screen == .nothingToStudy)
    }

    @Test func nothingDueOffersReviewAnywayAndThenRunsASession() async throws {
        let later = now.addingTimeInterval(86_400 * 10)
        var reviews: [ItemID: ReviewState] = [:]
        for item in PreviewCatalog.scenario.items {
            reviews[item.id] = ReviewState(
                itemID: item.id,
                repetitions: 2,
                intervalDays: 10,
                easeFactor: 2.5,
                due: later,
                lastOutcome: .correct,
                lastReviewed: now
            )
        }
        let store = InMemoryProgressStore(initial: ProgressSnapshot(reviews: reviews, attempts: []))
        let model = makeModel(store: store)
        await model.start()
        #expect(model.screen == .nothingDue)

        model.startReviewAnyway()
        let question = try asking(model)
        model.choose(try optionID(question, .canonical))
        await model.waitForPendingSaves()

        let snapshot = try await store.load()
        #expect(snapshot.attempts.count == 1)
        #expect(snapshot.reviews[question.item.id]?.repetitions == 3)
    }

    @Test func reviewAnywayIsIgnoredUnlessItWasOffered() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        await model.start()
        let before = model.screen
        model.startReviewAnyway()
        #expect(model.screen == before)
    }

    @Test func startingTwiceDoesNotReloadOrRestart() async throws {
        let model = makeModel(store: InMemoryProgressStore())
        await model.start()
        model.choose(try optionID(try asking(model), .canonical))
        await model.start()
        #expect(isFeedback(model))
    }
}

@MainActor
extension SessionViewModelTests {
    /// A scenario of fake items, big enough that the first question visibly varies with the seed.
    private func bigScenario(count: Int) -> Scenario {
        let items = (1...count).map { number in
            Item(
                id: ItemID(rawValue: "zz-\(number)"),
                scenarioID: ScenarioID(rawValue: "zz-big"),
                sourcePrompt: "zz prompt \(number)",
                register: .neutral,
                addressee: .any,
                canonical: "zz canonical \(number)",
                acceptedAnswers: ["zz canonical \(number)", "zz b", "zz c"],
                registerVariant: nil,
                distractors: ["zz w1 \(number)", "zz w2 \(number)", "zz w3 \(number)"],
                tokens: [],
                note: nil,
                reviewStatus: .unreviewed
            )
        }
        return Scenario(
            id: ScenarioID(rawValue: "zz-big"),
            title: "zz",
            subtitle: "zz",
            romanisationNote: nil,
            items: items,
            language: .tamil
        )
    }

    /// The item IDs of a session's questions in the order they are asked, answering each correctly.
    private func askedOrder(seed: UInt64, scenario: Scenario) async throws -> [String] {
        let model = SessionViewModel(
            scenario: scenario,
            dependencies: dependencies(store: InMemoryProgressStore()),
            random: .seeded(seed)
        )
        await model.start()
        var order: [String] = []
        while case .session(.asking(let question)) = model.screen {
            order.append(question.item.id.rawValue)
            model.choose(try optionID(question, .canonical))
            model.advance()
        }
        return order
    }
}

private enum ScreenError: Error {
    case notAsking
}
