/// An `ExamResultStore` that keeps the attempts in memory. For tests and previews; behaves like
/// `FileExamResultStore` minus the failure modes that only a disk can have.
public actor InMemoryExamResultStore: ExamResultStore {
    private var attempts: [ExamAttempt]

    public init(initial: [ExamAttempt] = []) {
        attempts = Array(initial.suffix(ExamHistory.maxAttempts))
    }

    public func load() async throws(ExamResultStoreError) -> [ExamAttempt] {
        attempts
    }

    public func append(_ attempt: ExamAttempt) async throws(ExamResultStoreError) {
        attempts = ExamHistory.appending(attempt, to: attempts)
    }

    public func erase() async throws(ExamResultStoreError) {
        attempts = []
    }
}
