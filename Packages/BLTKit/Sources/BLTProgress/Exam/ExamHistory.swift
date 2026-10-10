/// Pure rules about a list of exam attempts, shared by every `ExamResultStore` so they cannot drift.
/// Lists are oldest first.
public enum ExamHistory {
    /// A store keeps at most this many attempts and drops the oldest first.
    public static let maxAttempts = 20

    /// `attempts` with `attempt` added at the end, trimmed to the last `maxAttempts`.
    public static func appending(_ attempt: ExamAttempt, to attempts: [ExamAttempt]) -> [ExamAttempt] {
        Array((attempts + [attempt]).suffix(maxAttempts))
    }

    /// The attempt with the highest share correct. When two have the same share, the later one in the
    /// list wins. An attempt with no questions counts as zero. `nil` for an empty list.
    public static func best(in attempts: [ExamAttempt]) -> ExamAttempt? {
        var best: ExamAttempt?
        for attempt in attempts {
            guard let current = best else {
                best = attempt
                continue
            }
            // Cross-multiplied so no floating point is involved: a/b >= c/d is a*d >= c*b.
            let candidateCorrect = attempt.total > 0 ? attempt.correct : 0
            let currentCorrect = current.total > 0 ? current.correct : 0
            let candidateTotal = max(attempt.total, 1)
            let currentTotal = max(current.total, 1)
            if candidateCorrect * currentTotal >= currentCorrect * candidateTotal {
                best = attempt
            }
        }
        return best
    }

    /// Whether any attempt in the list passed.
    public static func hasPassed(in attempts: [ExamAttempt]) -> Bool {
        attempts.contains { $0.passed }
    }
}
