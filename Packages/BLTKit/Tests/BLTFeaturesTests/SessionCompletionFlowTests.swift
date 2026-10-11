import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

/// Whole-flow rules that used to be checked by driving the screens in UI tests (DECISIONS 045): what a
/// session writes, and what Home then shows. Each test runs a real `SessionViewModel` and a real
/// `HomeViewModel` over one in-memory store and the two fake items of `PreviewCatalog`, so a rule is
/// checked in milliseconds instead of a minute of simulator time.
///
/// The order of the two items is random, so tests ask for an item by identity rather than by position.
@MainActor
struct SessionCompletionFlowTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)
    private let respectful = PreviewCatalog.respectfulItem
    private let neutral = PreviewCatalog.neutralItem

    private func dependencies(store: some ProgressStore) -> AppDependencies {
        let fixedNow = now
        return AppDependencies(
            catalog: PreviewCatalog.catalog,
            language: .tamil,
            store: store,
            scheduler: SM2Scheduler(),
            now: { fixedNow }
        )
    }

    private func startSession(store: some ProgressStore, seed: UInt64 = 7) async -> SessionViewModel {
        let model = SessionViewModel(
            scenario: PreviewCatalog.scenario,
            dependencies: dependencies(store: store),
            random: .seeded(seed)
        )
        await model.start()
        return model
    }

    /// The completion percent Home shows for the fixture scenario, read through a fresh `HomeViewModel`.
    private func homePercent(store: some ProgressStore) async throws -> Int {
        let home = HomeViewModel(dependencies: dependencies(store: store))
        await home.load()
        return try #require(home.scenarios.first).completionPercent
    }

    private func asking(_ model: SessionViewModel) throws -> Question {
        guard case .session(.asking(let question)) = model.screen else { throw FlowScreenError.notAsking }
        return question
    }

    private func option(_ question: Question, _ kind: AnswerOption.Kind) throws -> Int {
        try #require(question.options.first { $0.kind == kind }).id
    }

    private func answer(_ model: SessionViewModel, as kind: AnswerOption.Kind) throws {
        model.choose(try option(try asking(model), kind))
    }

    private func isFinished(_ model: SessionViewModel) -> Bool {
        if case .session(.finished) = model.screen { return true }
        return false
    }

    /// Answers whatever comes first correctly until `target` is on screen (at most once with two items).
    private func advance(_ model: SessionViewModel, toItem target: ItemID) throws {
        for _ in 0..<2 {
            if try asking(model).item.id == target { return }
            try answer(model, as: .canonical)
            model.advance()
        }
        throw FlowScreenError.notAsking
    }

    // MARK: Completion on Home

    @Test func correctAnswersRaiseCompletionFromZeroToFiftyToOneHundred() async throws {
        let store = InMemoryProgressStore()
        #expect(try await homePercent(store: store) == 0)

        // Session one: one correct answer, then the learner ends the session (what the End control does).
        let first = await startSession(store: store)
        try answer(first, as: .canonical)
        await first.endSession()
        #expect(try await homePercent(store: store) == 50)

        // Session two: the only unseen item is the one asked; answering it finishes the scenario.
        let second = await startSession(store: store)
        try answer(second, as: .canonical)
        second.advance()
        await second.waitForPendingSaves()
        #expect(isFinished(second))
        #expect(try await homePercent(store: store) == 100)
    }

    @Test func aWrongAnswerDoesNotCompleteTheItem() async throws {
        let store = InMemoryProgressStore()
        let model = await startSession(store: store)

        try answer(model, as: .distractor)
        await model.endSession()

        #expect(try await homePercent(store: store) == 0)
    }

    @Test func theOtherRegisterAnswerDoesNotCompleteTheItem() async throws {
        let store = InMemoryProgressStore()
        let model = await startSession(store: store)
        // If the neutral item comes first it is answered correctly on the way (50%); otherwise nothing is.
        let expectedPercent = try asking(model).item.id == respectful.id ? 0 : 50
        try advance(model, toItem: respectful.id)

        try answer(model, as: .registerVariant)
        await model.endSession()

        #expect(try await homePercent(store: store) == expectedPercent)
        let stored = try await store.load()
        #expect(stored.reviews[respectful.id]?.lastOutcome == .wrongRegister)
    }

    @Test func aMissedItemAnsweredCorrectlyOnReturnStaysIncomplete() async throws {
        let store = InMemoryProgressStore()
        let model = await startSession(store: store)
        let missed = try asking(model).item.id

        try answer(model, as: .distractor)
        model.advance()
        try answer(model, as: .canonical)
        model.advance()
        // The missed item comes back and is answered correctly, but only the first attempt is recorded.
        #expect(try asking(model).item.id == missed)
        try answer(model, as: .canonical)
        model.advance()
        await model.waitForPendingSaves()

        #expect(isFinished(model))
        #expect(try await homePercent(store: store) == 50)
        let stored = try await store.load()
        #expect(stored.attempts.count == 2)
        #expect(stored.reviews[missed]?.lastOutcome == .wrong)
    }

    // MARK: Ending a session

    @Test func anAnswerGivenBeforeEndingIsCounted() async throws {
        let store = InMemoryProgressStore()
        let model = await startSession(store: store)
        let answered = try asking(model).item.id
        try answer(model, as: .canonical)

        await model.endSession()

        #expect(try await homePercent(store: store) == 50)
        let stored = try await store.load()
        #expect(stored.attempts.map(\.itemID) == [answered])
    }

    // MARK: Feedback and requeueing

    @Test(arguments: [
        (AnswerOption.Kind.canonical, Outcome.correct),
        (AnswerOption.Kind.registerVariant, Outcome.wrongRegister),
        (AnswerOption.Kind.distractor, Outcome.wrong)
    ])
    func eachKindOfOptionLeadsToItsOwnFeedback(kind: AnswerOption.Kind, outcome: Outcome) async throws {
        let model = await startSession(store: InMemoryProgressStore())
        // The register variant exists only on the respectful item.
        if kind == .registerVariant { try advance(model, toItem: respectful.id) }

        try answer(model, as: kind)

        guard case .session(.feedback(_, _, let verdict)) = model.screen else {
            Issue.record("expected the feedback screen")
            return
        }
        #expect(verdict.outcome == outcome)
    }

    @Test func aMissedItemComesBackBeforeTheSessionCanFinish() async throws {
        let model = await startSession(store: InMemoryProgressStore())
        let missed = try asking(model).item.id
        try answer(model, as: .distractor)
        model.advance()

        // The other item comes next, then the missed one again.
        let other = try asking(model).item.id
        #expect(other != missed)
        try answer(model, as: .canonical)
        model.advance()

        #expect(!isFinished(model), "The session must not finish with a missed item")
        #expect(try asking(model).item.id == missed)
    }
}

private enum FlowScreenError: Error {
    case notAsking
}
