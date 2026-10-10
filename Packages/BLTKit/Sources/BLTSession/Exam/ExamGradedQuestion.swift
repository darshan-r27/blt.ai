/// One question of a finished exam, graded.
public struct ExamGradedQuestion: Sendable, Equatable {
    public let source: ExamQuestionSource
    /// `true` only when the learner chose the canonical option. Unanswered counts as `false`.
    public let isCorrect: Bool

    public init(source: ExamQuestionSource, isCorrect: Bool) {
        self.source = source
        self.isCorrect = isCorrect
    }
}
