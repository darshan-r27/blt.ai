import BLTProgress
import Foundation

/// Appends one finished chapter to the practice log and works out what it changed.
///
/// Reads the log, appends, and computes the streak before and after from the same moment. It never erases
/// or rewrites the log itself: if the store cannot read or write it (a damaged file, a full disk) the error
/// is thrown and nothing is reported as recorded, so `onRecorded` (which reschedules reminders) only runs
/// for a chapter that really is in the log.
struct PracticeRecorder: Sendable {
    let log: any PracticeLogStore
    let calendar: Calendar
    let calculator: StreakCalculator
    let onRecorded: @Sendable (StreakSummary) async -> Void

    func record(answered: Int, finishedAt: Date) async throws(PracticeLogError) -> PracticeOutcome {
        let session = PracticeSession(finishedAt: finishedAt, answered: answered)
        let existing = try await log.load()
        try await log.append(session)
        let before = calculator.summary(for: existing, now: finishedAt, calendar: calendar)
        let after = calculator.summary(for: existing.appending(session), now: finishedAt, calendar: calendar)
        await onRecorded(after)
        return PracticeOutcome(finishedAt: finishedAt, before: before, after: after)
    }
}
