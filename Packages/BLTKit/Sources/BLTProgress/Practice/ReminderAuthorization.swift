/// Whether the learner has allowed notifications, reduced to what the app needs to know.
public enum ReminderAuthorization: Sendable, Equatable {
    /// The app has not asked yet.
    case notDetermined
    /// The learner said no, or turned notifications off in iOS Settings.
    case denied
    /// Reminders may be scheduled.
    case authorized
}
