/// Persistence for one course's practice log. One store per course; the app decides which file it is.
public protocol PracticeLogStore: Sendable {
    /// An empty log when nothing has been recorded yet.
    func load() async throws(PracticeLogError) -> PracticeLog
    /// Adds a finished session. A session with no answers (`countsTowardStreak == false`) is ignored:
    /// nothing is written and no error is thrown.
    func append(_ session: PracticeSession) async throws(PracticeLogError)
    /// Removes the whole log (Reset progress). Succeeds when there is none.
    func erase() async throws(PracticeLogError)
}
