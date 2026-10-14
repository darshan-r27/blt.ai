import BLTCore
import BLTProgress

/// The daily-practice pieces that belong to the device rather than to one course (DECISIONS 047): the reminder
/// choices, the notification scheduler, how to open the app's page in iOS Settings, and a way to reach either
/// course's practice log (to count finished sessions across both courses).
///
/// Built once by the composition root. The defaults are in-memory and inert, so previews and tests that do not
/// care about practice need to pass nothing.
public struct PracticeServices: Sendable {
    /// Reminders on or off, quiet hours, and whether the learner was already asked about notifications.
    public let preferences: any PracticePreferencesStore
    /// Asks for permission and schedules or cancels the local reminders.
    public let reminders: any ReminderScheduling
    /// Either course's practice log. The composition root builds each log once, so this returns the same store
    /// that course's `AppDependencies.practiceLog` holds.
    public let logs: @Sendable (CourseLanguage) -> any PracticeLogStore
    /// Opens this app's page in iOS Settings. A closure because SwiftUI's `openURL` is on the forbidden-API list:
    /// the app target supplies it.
    public let openSystemSettings: @MainActor @Sendable () -> Void

    public init(
        preferences: any PracticePreferencesStore = InMemoryPracticePreferencesStore(),
        reminders: any ReminderScheduling = FakeReminderScheduler(),
        logs: @escaping @Sendable (CourseLanguage) -> any PracticeLogStore = { _ in InMemoryPracticeLogStore() },
        openSystemSettings: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.preferences = preferences
        self.reminders = reminders
        self.logs = logs
        self.openSystemSettings = openSystemSettings
    }
}
