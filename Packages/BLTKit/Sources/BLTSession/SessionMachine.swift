import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

/// The question-by-question state machine for one session. A value type with no clock or randomness of its own:
/// the caller supplies `now` and the random number generator, so tests are deterministic.
///
/// Requeue rule: a `.notQuite` answer puts the item back so it is the third question after the one just
/// answered (or last, if fewer than two questions remain), rebuilt with a fresh shuffle. At most two requeues
/// per item per session. `.wrongRegister` answers are not requeued. Only an item's first presentation yields an
/// `AttemptRecord` and counts toward the `SessionResult`.
public struct SessionMachine: Sendable {
    /// Questions still to come, not including the one currently shown.
    private var upcoming: [Question]
    private var requeuesByItem: [ItemID: Int] = [:]
    private var firstAttempted: Set<ItemID> = []
    private var correctCount = 0
    private var wrongRegisterCount = 0
    private var wrongCount = 0
    private let builder = QuestionBuilder()

    public private(set) var state: SessionState
    /// Total requeues so far, across all items.
    public private(set) var requeuedCount = 0

    /// Items that cannot be built into a four-option question are skipped.
    public init(items: [Item], using rng: inout some RandomNumberGenerator) {
        var questions: [Question] = []
        for item in items {
            if let question = QuestionBuilder().makeQuestion(for: item, using: &rng) {
                questions.append(question)
            }
        }
        if questions.isEmpty {
            upcoming = []
            state = .finished(SessionResult(correctCount: 0, wrongRegisterCount: 0, wrongCount: 0))
        } else {
            let first = questions.removeFirst()
            upcoming = questions
            state = .asking(first)
        }
    }

    /// Legal only in `.asking`; otherwise, or for an unknown option ID, a no-op returning `nil`.
    public mutating func choose(
        _ optionID: Int,
        at now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> AttemptRecord? {
        guard case .asking(let question) = state, let verdict = question.verdict(for: optionID) else { return nil }
        state = .feedback(question, chosen: optionID, verdict: verdict)

        if case .notQuite = verdict {
            requeue(question.item, using: &rng)
        }

        guard firstAttempted.insert(question.item.id).inserted else { return nil }
        switch verdict.outcome {
        case .correct: correctCount += 1
        case .wrongRegister: wrongRegisterCount += 1
        case .wrong: wrongCount += 1
        }
        return AttemptRecord(itemID: question.item.id, outcome: verdict.outcome, date: now)
    }

    /// Legal only in `.feedback`; otherwise a no-op.
    public mutating func advance(using rng: inout some RandomNumberGenerator) {
        guard case .feedback = state else { return }
        if upcoming.isEmpty {
            state = .finished(
                SessionResult(
                    correctCount: correctCount,
                    wrongRegisterCount: wrongRegisterCount,
                    wrongCount: wrongCount
                )
            )
        } else {
            state = .asking(upcoming.removeFirst())
        }
    }

    private mutating func requeue(_ item: Item, using rng: inout some RandomNumberGenerator) {
        let used = requeuesByItem[item.id, default: 0]
        guard used < 2, let rebuilt = builder.makeQuestion(for: item, using: &rng) else { return }
        requeuesByItem[item.id] = used + 1
        requeuedCount += 1
        upcoming.insert(rebuilt, at: min(2, upcoming.count))
    }
}
