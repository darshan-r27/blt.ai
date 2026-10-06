public enum Verdict: Sendable, Equatable {
    /// Chose the canonical form.
    case correct
    /// Chose the register variant: right sentence, wrong register for this person.
    case wrongRegister(correct: String)
    /// Chose a distractor. The item is requeued.
    case notQuite(correct: String)

    public var outcome: Outcome {
        switch self {
        case .correct: .correct
        case .wrongRegister: .wrongRegister
        case .notQuite: .wrong
        }
    }
}
