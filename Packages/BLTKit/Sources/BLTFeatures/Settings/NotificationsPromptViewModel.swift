import BLTProgress
import Foundation
import Observation

/// Drives the pre-prompt shown before the system's notification question. It explains in one line why
/// reminders exist, then either asks the system (Allow) or remembers the answer and leaves (Not now).
///
/// Both choices set `hasAskedForNotifications`, so the app never asks again by itself. This type does not
/// import `UserNotifications`: the system question goes through `ReminderScheduling`.
@MainActor
@Observable
final class NotificationsPromptViewModel: Identifiable {
    enum Outcome: Equatable {
        /// The learner allowed notifications; reminders are on.
        case allowed
        /// The learner said Allow here but the system said no; reminders are off.
        case notGranted
        /// The learner chose Not now (or closed the prompt); nothing was asked of the system.
        case notNow
    }

    /// What an answer does to the saved reminders choice.
    private enum RemindersChange {
        case turnOn
        case turnOff
        case keep
    }

    /// The one-line reason, shown first. Plain and calm: no urgency, no phrase, no name.
    static let reason = "Would you like a gentle reminder before your streak lapses?"
    static let detail = "You would get at most two short notifications, never during your quiet hours. "
        + "Nothing leaves your device, and you can change this any time in Settings."
    static let saveFailureMessage = "Your choice could not be saved. You can try again, or close this and use Settings."

    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// Set once, when the choice has been saved and the settings owner told.
    private(set) var outcome: Outcome?
    private(set) var isWorking = false
    /// True after a save failed. The prompt stays open so the failure is seen.
    private(set) var saveFailed = false

    private let reminders: any ReminderScheduling
    private let preferences: any PracticePreferencesStore
    private let onPracticeSettingsChanged: @Sendable () async -> Void
    private let onFinished: @MainActor (Outcome) -> Void

    /// `onPracticeSettingsChanged` runs after a saved choice so the owner can reschedule; `onFinished` runs
    /// once, last, so the owner can close the prompt.
    init(
        reminders: any ReminderScheduling,
        preferences: any PracticePreferencesStore,
        onPracticeSettingsChanged: @escaping @Sendable () async -> Void = {},
        onFinished: @escaping @MainActor (Outcome) -> Void = { _ in }
    ) {
        self.reminders = reminders
        self.preferences = preferences
        self.onPracticeSettingsChanged = onPracticeSettingsChanged
        self.onFinished = onFinished
    }

    /// Wired to Allow. Shows the system question, then saves the answer.
    func allow() async {
        guard outcome == nil, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let granted = await reminders.requestAuthorization()
        await finish(granted ? .allowed : .notGranted, reminders: granted ? .turnOn : .turnOff)
    }

    /// Wired to Not now. Remembers that the learner was asked; asks the system nothing.
    func notNow() async {
        guard outcome == nil, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await finish(.notNow, reminders: .keep)
    }

    /// The prompt was swiped away. Counts as Not now and closes even if the answer cannot be saved, because
    /// there is nothing left to retry on.
    func dismissed() async {
        guard outcome == nil, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await finish(.notNow, reminders: .keep, closesEvenIfSaveFails: true)
    }

    private func finish(
        _ result: Outcome,
        reminders change: RemindersChange,
        closesEvenIfSaveFails: Bool = false
    ) async {
        saveFailed = false
        do throws(PracticePreferencesError) {
            var updated = try await preferences.load()
            updated.hasAskedForNotifications = true
            switch change {
            case .turnOn: updated.remindersEnabled = true
            case .turnOff: updated.remindersEnabled = false
            case .keep: break
            }
            try await preferences.save(updated)
        } catch {
            saveFailed = true
            if closesEvenIfSaveFails {
                outcome = result
                onFinished(result)
            }
            return
        }
        await onPracticeSettingsChanged()
        outcome = result
        onFinished(result)
    }
}
