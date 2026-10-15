import BLTProgress
import Foundation
import os
import UserNotifications

/// Schedules the two streak reminders as local notifications: nothing leaves the device. This is the only
/// file in the app that imports `UserNotifications`.
///
/// An actor, because `UNUserNotificationCenter` is not `Sendable`: the center never leaves it.
///
/// Both notification identifiers are fixed, so every reschedule removes the two pending requests and adds
/// the new ones.
actor LocalReminderScheduler: ReminderScheduling {
    private static let logger = Logger(subsystem: "ai.blt.app", category: "reminders")

    private let center: UNUserNotificationCenter
    private let now: @Sendable () -> Date

    init(center: UNUserNotificationCenter = .current(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.center = center
        self.now = now
    }

    var authorizationStatus: ReminderAuthorization {
        get async {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .authorized, .provisional, .ephemeral: return .authorized
            @unknown default: return .denied
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            let reason = error.localizedDescription
            Self.logger.error("Notification permission request failed: \(reason, privacy: .private)")
            return false
        }
    }

    func schedule(_ plan: ReminderPlan) async {
        center.removePendingNotificationRequests(withIdentifiers: ReminderSlot.allCases.map(\.identifier))
        guard await authorizationStatus == .authorized else {
            return
        }
        for reminder in plan.reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            // An interval trigger names an absolute moment, so travel or a time-zone change cannot shift it.
            let seconds = max(1, reminder.fireDate.timeIntervalSince(now()))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                Self.logger.error("Could not schedule a reminder: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    func cancelAll() async {
        center.removePendingNotificationRequests(withIdentifiers: ReminderSlot.allCases.map(\.identifier))
    }

    #if DEBUG
    func pendingReminders() async -> [PlannedReminder] {
        let requests = await center.pendingNotificationRequests()
        return requests.compactMap { request in
            guard let slot = ReminderSlot(identifier: request.identifier),
                  let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
                  let fireDate = trigger.nextTriggerDate() else {
                return nil
            }
            return PlannedReminder(
                slot: slot,
                fireDate: fireDate,
                title: request.content.title,
                body: request.content.body
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }
    #endif
}
