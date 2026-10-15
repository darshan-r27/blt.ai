/// What to schedule after a finished session: zero, one or two reminders, in slot order (first, then second). An empty plan
/// is meaningful: scheduling it clears any older reminders.
public struct ReminderPlan: Sendable, Equatable {
    public static let empty = ReminderPlan(reminders: [])

    public let reminders: [PlannedReminder]

    public init(reminders: [PlannedReminder]) {
        self.reminders = reminders
    }

    public var isEmpty: Bool {
        reminders.isEmpty
    }
}
