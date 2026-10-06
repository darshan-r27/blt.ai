import BLTCore

/// Feedback colour comes only from this type. There is deliberately no red tone.
public enum FeedbackTone: Sendable, Equatable {
    case affirm
    case nudge
    case neutral

    public init(_ outcome: Outcome) {
        switch outcome {
        case .correct: self = .affirm
        case .wrongRegister: self = .nudge
        case .wrong: self = .neutral
        }
    }
}
