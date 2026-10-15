import Foundation

/// One notification to schedule: when it fires and what it says. The text carries the streak length and
/// the language only, never a phrase or the learner's name, because a lock screen is public.
public struct PlannedReminder: Sendable, Equatable {
    public let slot: ReminderSlot
    public let fireDate: Date
    public let title: String
    public let body: String

    public init(slot: ReminderSlot, fireDate: Date, title: String, body: String) {
        self.slot = slot
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }

    public var identifier: String {
        slot.identifier
    }
}
