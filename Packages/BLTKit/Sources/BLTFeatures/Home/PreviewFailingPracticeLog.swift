#if DEBUG
import BLTProgress

/// A practice log whose `load()` always throws, for previewing the calm "could not be read" note.
/// Appending and erasing succeed and do nothing.
struct PreviewFailingPracticeLog: PracticeLogStore {
    let loadError: PracticeLogError

    func load() async throws(PracticeLogError) -> PracticeLog {
        throw loadError
    }

    func append(_ session: PracticeSession) async throws(PracticeLogError) {}

    func erase() async throws(PracticeLogError) {}
}
#endif
