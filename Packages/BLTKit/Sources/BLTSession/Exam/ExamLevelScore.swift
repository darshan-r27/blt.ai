/// Correct and total counts for one level of an exam.
public struct ExamLevelScore: Sendable, Equatable {
    public let correct: Int
    public let total: Int

    public init(correct: Int, total: Int) {
        self.correct = correct
        self.total = total
    }
}
