import BLTCore
import Foundation

/// Works out when the two reminders should fire and what they say. Pure: the same inputs always give the
/// same plan, so every quiet-hours case can be tested without a clock or a notification center.
///
/// Rules (plan.md, "Daily practice"):
/// - The reminders are due 20 and 23 hours after the last finished session.
/// - One that lands in quiet hours moves to 30 minutes before those quiet hours began, which is the evening
///   before the moment it would have fired.
/// - If both end up at the same moment, only the first is kept.
/// - A moment that is not after `now` is dropped.
public struct ReminderPlanner: Sendable {
    /// How long before quiet hours begin a moved reminder fires.
    public static let leadBeforeQuietHours: TimeInterval = 30 * 60

    /// A window as long as nearly a whole day can push a reminder back more than once. After this many
    /// moves the reminder is dropped rather than looping.
    private static let maximumMoves = 3

    public init() {}

    /// - Parameters:
    ///   - lastSessionFinish: When the learner last finished a practice session.
    ///   - now: The current moment; reminders at or before it are dropped.
    ///   - calendar: Supplies the time zone that decides what "10 pm" means.
    ///   - quietHours: When reminders must not fire.
    ///   - context: The language being learned and the streak length; the text names both.
    public func plan(
        lastSessionFinish: Date,
        now: Date,
        calendar: Calendar,
        quietHours: QuietHours,
        context: ReminderContext
    ) -> ReminderPlan {
        var reminders: [PlannedReminder] = []
        for slot in ReminderSlot.allCases.sorted() {
            let due = lastSessionFinish.addingTimeInterval(TimeInterval(slot.hoursAfterSession) * 3600)
            guard let fireDate = allowedMoment(for: due, quietHours: quietHours, calendar: calendar),
                  fireDate > now,
                  !reminders.contains(where: { $0.fireDate == fireDate }) else {
                continue
            }
            let text = Self.text(for: slot, language: context.language, streakLength: context.streakLength)
            reminders.append(PlannedReminder(slot: slot, fireDate: fireDate, title: text.title, body: text.body))
        }
        return ReminderPlan(reminders: reminders)
    }

    /// The notification text. Names the streak length and the language and nothing else the learner typed
    /// or learned. Calm wording, no urgency.
    public static func text(
        for slot: ReminderSlot,
        language: CourseLanguage,
        streakLength: Int
    ) -> (title: String, body: String) {
        let name = language.displayName
        let streak = max(0, streakLength)
        let title = streak > 0 ? "\(streak) day streak" : "\(name) practice"
        switch slot {
        case .first:
            let body = streak > 0
                ? "A short \(name) chapter keeps it going."
                : "Ready for a short \(name) chapter?"
            return (title, body)
        case .second:
            let body = streak > 0
                ? "Whenever you are ready, a short \(name) chapter keeps your streak going."
                : "Whenever you are ready, a short \(name) chapter is here."
            return (title, body)
        }
    }

    private func allowedMoment(for due: Date, quietHours: QuietHours, calendar: Calendar) -> Date? {
        var moment = due
        for _ in 0..<Self.maximumMoves {
            guard let windowStart = quietHours.windowStart(containing: moment, calendar: calendar) else {
                return moment
            }
            moment = windowStart.addingTimeInterval(-Self.leadBeforeQuietHours)
        }
        return quietHours.contains(moment, calendar: calendar) ? nil : moment
    }
}
