/// How the learner did on the questions of one level in one exam attempt.
///
/// `level` is the lesson level the questions came from, or `nil` for the questions that are not tied to
/// a level (the new sentences built from the whole course). Plain numbers only: no question text.
public struct ExamLevelScore: Sendable, Codable, Equatable {
    public let level: Int?
    public let correct: Int
    public let total: Int

    public init(level: Int?, correct: Int, total: Int) {
        self.level = level
        self.correct = correct
        self.total = total
    }
}
