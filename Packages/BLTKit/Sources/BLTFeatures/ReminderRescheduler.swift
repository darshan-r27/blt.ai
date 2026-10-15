import BLTCore
import BLTProgress
import Foundation

/// Brings the two pending streak reminders in line with what is stored, for the language being learned.
///
/// It reads everything fresh (the preferences, the permission, this course's log) and then either schedules
/// the plan or cancels every reminder, so it can be called from anywhere (after a session, after a setting
/// changes, at launch, on return to the foreground) and always leaves the right thing pending. Calling it twice
/// in a row is harmless: the scheduler replaces its two fixed notifications each time.
///
/// Cancelled, never guessed: reminders are cancelled when they are switched off, when the system does not allow
/// them, when the course has no finished session (a new learner, or Reset progress), and when either file
/// cannot be read (a reminder built on a guess could be wrong, and a missing one is only a missed nudge).
/// The wording comes from `ReminderPlanner` and never contains a phrase or the learner's name.
struct ReminderRescheduler: Sendable {
    let language: CourseLanguage
    let log: any PracticeLogStore
    let preferences: any PracticePreferencesStore
    let reminders: any ReminderScheduling
    let calculator: StreakCalculator
    let now: @Sendable () -> Date
    /// The learner's calendar, read at each reschedule so a change of time zone is picked up.
    let calendar: @Sendable () -> Calendar

    func reschedule() async {
        guard let saved = await loadPreferences(), saved.remindersEnabled,
              await reminders.authorizationStatus == .authorized,
              let practiceLog = await loadLog() else {
            await reminders.cancelAll()
            return
        }
        let moment = now()
        let calendar = calendar()
        let summary = calculator.summary(for: practiceLog, now: moment, calendar: calendar)
        guard let lastSession = summary.lastSessionAt else {
            await reminders.cancelAll()
            return
        }
        let plan = ReminderPlanner().plan(
            lastSessionFinish: lastSession,
            now: moment,
            calendar: calendar,
            quietHours: saved.quietHours,
            context: ReminderContext(language: language, streakLength: summary.currentStreak)
        )
        await reminders.schedule(plan)
    }

    private func loadPreferences() async -> PracticePreferences? {
        do throws(PracticePreferencesError) {
            return try await preferences.load()
        } catch {
            return nil
        }
    }

    private func loadLog() async -> PracticeLog? {
        do throws(PracticeLogError) {
            return try await log.load()
        } catch {
            return nil
        }
    }
}
