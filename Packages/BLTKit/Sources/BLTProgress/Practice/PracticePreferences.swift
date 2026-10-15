/// The learner's daily-practice choices. Device-wide, not per course, and not progress: Reset progress
/// leaves them alone. The daily goal is not stored here; it is fixed at `StreakCalculator.defaultDailyGoal`.
public struct PracticePreferences: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 1

    /// The learner wants reminders. Reminders are only scheduled when the system also allows
    /// notifications, so this can be true while nothing is sent.
    public var remindersEnabled: Bool

    /// When reminders stay quiet. See `QuietHours`.
    public var quietHours: QuietHours

    /// The permission pre-prompt has been answered (Allow or Not now), so it is never shown again by
    /// itself. The Settings toggle remains the way back in.
    public var hasAskedForNotifications: Bool

    public let schemaVersion: Int

    public init(
        remindersEnabled: Bool = true,
        quietHours: QuietHours = .standard,
        hasAskedForNotifications: Bool = false
    ) {
        self.remindersEnabled = remindersEnabled
        self.quietHours = quietHours
        self.hasAskedForNotifications = hasAskedForNotifications
        schemaVersion = Self.currentSchemaVersion
    }

    /// What a device with no saved choices starts with.
    public static let standard = PracticePreferences()
}
