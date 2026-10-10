/// What `ExamMachine.answer(_:)` did with an answer.
public enum ExamAnswerResult: Sendable, Equatable {
    case accepted
    /// The question already has an answer. Answers cannot be changed.
    case alreadyAnswered
    /// The option id is not one of the current question's options.
    case unknownOption
    /// The exam is over, so there is nothing to answer.
    case finished
}
