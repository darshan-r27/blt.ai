import BLTCore

public enum SessionState: Sendable, Equatable {
    case asking(Question)
    case feedback(Question, chosen: Int, verdict: Verdict)
    case finished(SessionResult)
}
