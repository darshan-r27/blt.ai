import BLTProgress

/// What Home shows for the final exam (DECISIONS 041): whether it can be started, and the best result so far.
struct ExamEntry: Equatable {
    let isUnlocked: Bool
    let total: Int
    let passMarkPercent: Int
    let best: ExamAttempt?
    let historyUnreadable: Bool

    /// The pass mark in questions, rounded up, matching `ExamPaper.isPass`.
    var correctNeededToPass: Int {
        (passMarkPercent * total + 99) / 100
    }

    var summary: String {
        isUnlocked
            ? "\(total) questions in one sitting, no feedback until the end. Pass with \(correctNeededToPass)."
            : "Finish every level to unlock the final exam. \(total) questions, pass with \(correctNeededToPass)."
    }

    /// "Best: 82 of 100, passed", or a plain line when results cannot be read, or `nil` with no attempts.
    var bestLine: String? {
        if historyUnreadable { return "Your earlier results could not be read." }
        guard let best else { return nil }
        return "Best: \(best.correct) of \(best.total), \(best.passed ? "passed" : "not passed yet")"
    }
}
