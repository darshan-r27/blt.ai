import Foundation

/// The result of one sitting of the final exam (DECISIONS 041).
///
/// This is everything that is stored about an attempt: when it was taken, the score, whether it passed
/// and the score per level. It holds no question text, no prompts, no answers and no names, so a result
/// file reveals nothing about what the learner saw or typed.
public struct ExamAttempt: Sendable, Codable, Equatable {
    public let date: Date
    public let correct: Int
    public let total: Int
    public let passed: Bool
    public let levels: [ExamLevelScore]

    public init(date: Date, correct: Int, total: Int, passed: Bool, levels: [ExamLevelScore]) {
        self.date = date
        self.correct = correct
        self.total = total
        self.passed = passed
        self.levels = levels
    }
}
