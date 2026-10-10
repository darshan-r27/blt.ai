/// Persistence for the learner's exam attempts in one language (DECISIONS 041, 043).
///
/// Exam results live in their own store and file, apart from `ProgressStore`: an exam never writes a
/// review record. The caller chooses where the file lives, so the store knows no language.
public protocol ExamResultStore: Sendable {
    /// The stored attempts, oldest first. Empty when nothing has been stored yet.
    func load() async throws(ExamResultStoreError) -> [ExamAttempt]
    /// Adds an attempt at the end and keeps only the last `ExamHistory.maxAttempts`.
    func append(_ attempt: ExamAttempt) async throws(ExamResultStoreError)
    /// Removes every attempt. Succeeds when there are none.
    func erase() async throws(ExamResultStoreError)
}

extension ExamResultStore {
    /// The best stored attempt (see `ExamHistory.best(in:)`), or `nil` when there are none.
    public func bestAttempt() async throws(ExamResultStoreError) -> ExamAttempt? {
        ExamHistory.best(in: try await load())
    }

    /// Whether any stored attempt passed.
    public func hasPassed() async throws(ExamResultStoreError) -> Bool {
        ExamHistory.hasPassed(in: try await load())
    }
}
