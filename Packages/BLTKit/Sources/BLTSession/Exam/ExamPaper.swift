/// An ordered list of exam questions plus the rule for passing (DECISIONS 041).
/// The engine does not know where a paper comes from or which language it is for; the caller builds one paper
/// per language and keeps them apart.
public struct ExamPaper: Sendable, Equatable {
    /// The learner passes with at least this percentage of the questions correct.
    public static let passMarkPercent = 75

    public let sources: [ExamQuestionSource]

    public init(sources: [ExamQuestionSource]) {
        self.sources = sources
    }

    public var total: Int { sources.count }

    /// Integer arithmetic only, so there is no rounding at the boundary. An empty paper never passes.
    public static func isPass(correct: Int, total: Int) -> Bool {
        total > 0 && correct * 100 >= passMarkPercent * total
    }
}
