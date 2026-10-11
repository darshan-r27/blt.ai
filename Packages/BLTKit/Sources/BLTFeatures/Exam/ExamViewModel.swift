import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Observation

/// Drives one sitting of the final exam (DECISIONS 041): intro, one question at a time with no feedback, then
/// the result. The rules live in `ExamMachine`; this type only holds the screen state and saves the result.
///
/// The exam writes no review record and never touches scheduling. The only thing stored is the attempt's score
/// (`ExamAttempt`), once, when the exam ends.
@MainActor
@Observable
final class ExamViewModel {
    enum Phase: Equatable {
        case intro
        case asking
        case finished
    }

    private(set) var phase: Phase = .intro
    /// The question on screen while `phase == .asking`.
    private(set) var question: Question?
    /// 1-based position of the question on screen, and the length of the paper.
    private(set) var position = 0
    let total: Int
    private(set) var result: ExamResult?
    /// Set when the paper could not be turned into questions, so the exam did not start.
    private(set) var startFailed = false
    /// Set when the result could not be saved. The result is still shown; only the history misses it.
    private(set) var saveFailed = false
    /// Bound to the "End the exam?" alert. Setting it is not a confirmation; only `confirmEnd()` ends.
    var isConfirmingEnd = false

    let language: CourseLanguage
    private var machine: ExamMachine?
    private var random: SessionRandomSource
    private let paper: ExamPaper
    private let results: any ExamResultStore
    private let now: @Sendable () -> Date
    private var savedOnce = false
    private var saving: Task<Void, Never>?

    init(
        paper: ExamPaper,
        language: CourseLanguage,
        results: any ExamResultStore,
        now: @escaping @Sendable () -> Date,
        random: SessionRandomSource = .system
    ) {
        self.paper = paper
        self.language = language
        self.results = results
        self.now = now
        self.random = random
        total = paper.total
    }

    /// Shown on the intro screen and under the result. Plain, and never claims more than multiple choice can show.
    static func recognitionStatement(for language: CourseLanguage) -> String {
        "Passing shows you recognise natural spoken \(language.displayName), including sentences you have not "
            + "seen before. It does not show that you can say it; speaking practice comes later."
    }

    /// Correct answers needed to pass this paper, rounded up. The integer arithmetic matches `ExamPaper.isPass`.
    var correctNeededToPass: Int {
        (ExamPaper.passMarkPercent * total + 99) / 100
    }

    /// Starts the exam. Builds every question first, so a paper that cannot be built never shows a short exam.
    func begin() {
        guard phase == .intro else { return }
        guard let built = ExamMachine(paper: paper, using: &random) else {
            startFailed = true
            return
        }
        startFailed = false
        machine = built
        refresh()
    }

    /// Records the answer to the question on screen and moves straight on: the exam gives no feedback and
    /// does not allow going back.
    func choose(_ optionID: AnswerOption.ID) {
        guard phase == .asking, var current = machine else { return }
        guard current.answer(optionID) == .accepted else { return }
        current.advance()
        machine = current
        refresh()
    }

    func requestEnd() {
        guard phase == .asking else { return }
        isConfirmingEnd = true
    }

    func cancelEnd() {
        isConfirmingEnd = false
    }

    /// Wired only to the alert's destructive button. Unanswered questions count as wrong.
    func confirmEnd() {
        isConfirmingEnd = false
        guard phase == .asking, var current = machine else { return }
        current.finish()
        machine = current
        refresh()
    }

    /// Up to two levels the learner did clearly worse on than the pass mark, weakest first. A level at or above
    /// the pass mark is never listed, so a good result carries no "weak" label.
    var weakLevels: [Int] {
        guard let result else { return [] }
        return result.weakestLevels(limit: 2).filter { level in
            guard let score = result.byLevel[level] else { return false }
            return score.correct * 100 < ExamPaper.passMarkPercent * score.total
        }
    }

    /// Returns once the result has been written, or has failed to be. For tests and for the screen to settle on.
    func waitForSave() async {
        await saving?.value
    }

    // MARK: Private

    private func refresh() {
        guard let machine else { return }
        if machine.isFinished {
            result = machine.result
            question = nil
            phase = .finished
            saving = Task { await saveAttempt() }
        } else {
            question = machine.currentQuestion
            position = machine.currentIndex + 1
            phase = .asking
        }
    }

    /// Stores the score once. Nothing but numbers is written (`ExamAttempt` holds no question text).
    private func saveAttempt() async {
        guard let result, !savedOnce else { return }
        savedOnce = true
        let levels = result.byLevel
            .map { BLTProgress.ExamLevelScore(level: $0.key, correct: $0.value.correct, total: $0.value.total) }
            .sorted { ($0.level ?? Int.max) < ($1.level ?? Int.max) }
        let attempt = ExamAttempt(
            date: now(),
            correct: result.correct,
            total: result.total,
            passed: result.passed,
            levels: levels
        )
        do throws(ExamResultStoreError) {
            try await results.append(attempt)
        } catch {
            saveFailed = true
        }
    }
}
