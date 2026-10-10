import BLTCatalog
import BLTCore

/// The question-by-question state machine for one sitting of the final exam (DECISIONS 041). A value type with
/// no clock or randomness of its own: the caller supplies the random number generator, so tests are deterministic.
///
/// Rules: one question at a time, one answer per question, forward only, no feedback and no verdict until the
/// end. Only the canonical option scores; the register variant and the distractors are wrong. `finish()` ends
/// the exam early and unanswered questions count as wrong. The machine touches no scheduling or progress records.
public struct ExamMachine: Sendable {
    private struct Entry: Sendable {
        let paperIndex: Int
        let question: Question
        var chosen: AnswerOption.ID?
    }

    /// Questions in the order they are shown.
    private var entries: [Entry]
    private let sources: [ExamQuestionSource]
    private var position = 0
    private var ended = false

    /// Returns `nil` when any item cannot be built into a four-option question, so a paper is never silently
    /// shortened. An empty paper is allowed and is finished from the start.
    public init?(paper: ExamPaper, using rng: inout some RandomNumberGenerator) {
        let builder = QuestionBuilder()
        var built: [Entry] = []
        for (index, source) in paper.sources.enumerated() {
            guard let question = builder.makeQuestion(for: source.item, using: &rng) else { return nil }
            built.append(Entry(paperIndex: index, question: question, chosen: nil))
        }
        sources = paper.sources
        entries = built.shuffled(using: &rng)
        ended = built.isEmpty
    }

    public var total: Int { entries.count }

    public var isFinished: Bool { ended }

    /// The question on screen, or `nil` once the exam is over.
    public var currentQuestion: Question? {
        ended ? nil : entries[position].question
    }

    /// Zero-based position of the current question; equals `total` once the exam is over.
    public var currentIndex: Int { ended ? total : position }

    /// Questions with an answer so far.
    public var answeredCount: Int { entries.filter { $0.chosen != nil }.count }

    public var remaining: Int { total - answeredCount }

    /// `true` when the current question already has its answer and `advance()` will move on.
    public var currentIsAnswered: Bool {
        !ended && entries[position].chosen != nil
    }

    /// Records the answer to the current question. The exam gives no feedback, so nothing about correctness is
    /// returned. Call `advance()` to move on.
    @discardableResult
    public mutating func answer(_ optionID: AnswerOption.ID) -> ExamAnswerResult {
        guard !ended else { return .finished }
        guard entries[position].chosen == nil else { return .alreadyAnswered }
        guard entries[position].question.options.contains(where: { $0.id == optionID }) else { return .unknownOption }
        entries[position].chosen = optionID
        return .accepted
    }

    /// Moves to the next question once the current one is answered, and ends the exam after the last one.
    /// A no-op returning `false` when the current question is unanswered or the exam is over: there is no
    /// skipping and no going back.
    @discardableResult
    public mutating func advance() -> Bool {
        guard currentIsAnswered else { return false }
        if position + 1 < entries.count {
            position += 1
        } else {
            ended = true
        }
        return true
    }

    /// Ends the exam now. Unanswered questions count as wrong.
    public mutating func finish() {
        ended = true
    }

    /// The verdict, or `nil` until the exam is over.
    public var result: ExamResult? {
        guard ended else { return nil }
        var correctByPaperIndex: [Int: Bool] = [:]
        for entry in entries {
            let chosenKind = entry.chosen.flatMap { id in entry.question.options.first { $0.id == id }?.kind }
            correctByPaperIndex[entry.paperIndex] = chosenKind == .canonical
        }
        let graded = sources.indices.map { index in
            ExamGradedQuestion(source: sources[index], isCorrect: correctByPaperIndex[index] ?? false)
        }
        return ExamResult(graded: graded)
    }
}
