/// Tally of a finished session. Counts first attempts only: a requeued presentation never changes it.
public struct SessionResult: Sendable, Equatable {
    public let correctCount: Int
    public let wrongRegisterCount: Int
    public let wrongCount: Int

    public init(correctCount: Int, wrongRegisterCount: Int, wrongCount: Int) {
        self.correctCount = correctCount
        self.wrongRegisterCount = wrongRegisterCount
        self.wrongCount = wrongCount
    }

    /// Number of distinct items answered at least once.
    public var total: Int { correctCount + wrongRegisterCount + wrongCount }
}
