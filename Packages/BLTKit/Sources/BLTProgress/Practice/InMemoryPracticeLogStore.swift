/// A `PracticeLogStore` that keeps everything in memory. For tests and previews; behaves like
/// `FilePracticeLogStore` minus the failure modes that only a disk can have.
public actor InMemoryPracticeLogStore: PracticeLogStore {
    private var log: PracticeLog

    public init(initial: PracticeLog = .empty) {
        log = initial
    }

    public func load() async throws(PracticeLogError) -> PracticeLog {
        log
    }

    public func append(_ session: PracticeSession) async throws(PracticeLogError) {
        log = log.appending(session)
    }

    public func erase() async throws(PracticeLogError) {
        log = .empty
    }
}
