import BLTCore
import BLTProgress

extension PracticeServices {
    /// Finished practice sessions across both courses, counting the one that just ended. A log that cannot be
    /// read counts as none: the pre-prompt is then not offered, which is the calm choice.
    func finishedSessionCount() async -> Int {
        var total = 0
        for language in CourseLanguage.allCases {
            do throws(PracticeLogError) {
                total += try await logs(language).load().sessions.count
            } catch {
                continue
            }
        }
        return total
    }

    /// The pre-prompt to show now, or `nil` when it must not be shown: only at the end of the very first
    /// finished session, only if the learner was never asked, and only while the system has not been asked
    /// either (`NotificationsPromptRule`). An unreadable preferences file means "do not ask".
    ///
    /// `onPracticeSettingsChanged` runs after the learner's answer is saved (the host reschedules); `onFinished`
    /// runs last, so the host can close the sheet.
    @MainActor
    func notificationsPromptIfDue(
        onPracticeSettingsChanged: @escaping @Sendable () async -> Void,
        onFinished: @escaping @MainActor () -> Void
    ) async -> NotificationsPromptViewModel? {
        let hasAsked: Bool
        do throws(PracticePreferencesError) {
            hasAsked = try await preferences.load().hasAskedForNotifications
        } catch {
            return nil
        }
        let authorization = await reminders.authorizationStatus
        let count = await finishedSessionCount()
        guard NotificationsPromptRule.shouldAsk(
            finishedSessionCount: count,
            hasAskedBefore: hasAsked,
            authorization: authorization
        ) else {
            return nil
        }
        return NotificationsPromptViewModel(
            reminders: reminders,
            preferences: preferences,
            onPracticeSettingsChanged: onPracticeSettingsChanged,
            onFinished: { _ in onFinished() }
        )
    }
}
