/// Puts reminders on the device. The only implementation that talks to the system lives in the app target;
/// tests and previews use `FakeReminderScheduler`.
public protocol ReminderScheduling: Sendable {
    /// Asks the system for permission to show notifications. The app calls this after the first finished
    /// session, once the learner has seen why. Returns whether permission is now granted.
    func requestAuthorization() async -> Bool

    var authorizationStatus: ReminderAuthorization { get async }

    /// Replaces any reminders scheduled earlier with this plan. Does nothing if notifications are not
    /// allowed.
    func schedule(_ plan: ReminderPlan) async

    /// Removes every pending reminder.
    func cancelAll() async

    #if DEBUG
    /// The reminders the system is holding, earliest first. For checking a build by hand; not in release.
    func pendingReminders() async -> [PlannedReminder]
    #endif
}
