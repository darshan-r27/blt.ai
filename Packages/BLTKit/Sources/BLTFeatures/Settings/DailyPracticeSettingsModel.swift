import BLTProgress
import Foundation
import Observation

/// Drives the "Daily practice" section of Settings: reminders on or off, quiet hours, and the read-only
/// daily goal. Owned by `SettingsViewModel`. It never imports `UserNotifications`; permission and
/// scheduling go through `ReminderScheduling`.
///
/// Every change is saved first and only then announced through `onPracticeSettingsChanged`, so the owner
/// that reschedules always reads what was saved. A change that cannot be saved is reported and leaves the
/// screen showing what is actually stored.
@MainActor
@Observable
final class DailyPracticeSettingsModel {
    /// The one calm message under the section, if any.
    enum Notice: Equatable {
        case couldNotLoad
        case couldNotSave
        case quietHoursNeedDifferentTimes
    }

    /// What is stored. `.standard` until `refresh()` has read the file.
    private(set) var preferences = PracticePreferences.standard
    private(set) var authorization = ReminderAuthorization.notDetermined
    /// True when the preferences file could not be read; the controls are then off rather than guessing.
    private(set) var loadFailed = false
    private(set) var notice: Notice?
    /// Non-nil exactly while the permission pre-prompt is open.
    private(set) var prompt: NotificationsPromptViewModel?

    /// The daily goal is fixed for now and is not stored.
    let dailyGoal = StreakCalculator.defaultDailyGoal

    private let store: any PracticePreferencesStore
    private let reminders: any ReminderScheduling
    private let calendar: Calendar
    private let onPracticeSettingsChanged: @Sendable () async -> Void
    private let openSystemSettings: @MainActor () -> Void

    init(
        store: any PracticePreferencesStore,
        reminders: any ReminderScheduling,
        calendar: Calendar,
        onPracticeSettingsChanged: @escaping @Sendable () async -> Void,
        openSystemSettings: @escaping @MainActor () -> Void
    ) {
        self.store = store
        self.reminders = reminders
        self.calendar = calendar
        self.onPracticeSettingsChanged = onPracticeSettingsChanged
        self.openSystemSettings = openSystemSettings
    }

    // MARK: What the section shows

    /// On only when the learner wants reminders and the system allows them, so the toggle never claims
    /// reminders that cannot arrive.
    var remindersAreOn: Bool {
        preferences.remindersEnabled && authorization == .authorized
    }

    /// The toggle cannot do anything while notifications are off in iOS Settings or the file is unreadable.
    var canChangeReminders: Bool {
        !loadFailed && authorization != .denied
    }

    var canChangeQuietHours: Bool { !loadFailed }

    var notificationsAreDenied: Bool { authorization == .denied }

    static let deniedExplanation = "Notifications are turned off for this app in iOS Settings, "
        + "so no reminders can be sent. You can turn them on there whenever you like."

    var quietStartHour: Int { preferences.quietHours.startMinute / 60 }
    var quietEndHour: Int { preferences.quietHours.endMinute / 60 }

    var dailyGoalText: String {
        dailyGoal == 1 ? "1 chapter a day" : "\(dailyGoal) chapters a day"
    }

    var noticeMessage: String? {
        switch notice {
        case .couldNotLoad:
            "Your reminder settings could not be read, so they cannot be changed right now. Nothing was overwritten."
        case .couldNotSave:
            "That change could not be saved. Your settings are as they were. You can try again."
        case .quietHoursNeedDifferentTimes:
            "Quiet hours need different start and end times. Your quiet hours are unchanged."
        case nil:
            nil
        }
    }

    /// "10 PM" in the learner's locale. Hour precision is all the pickers offer.
    func hourLabel(_ hour: Int) -> String {
        let components = DateComponents(year: 2001, month: 1, day: 1, hour: hour)
        let date = calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
        let style = Date.FormatStyle(
            locale: calendar.locale ?? .current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return date.formatted(style.hour())
    }

    // MARK: Actions

    /// Reads the saved preferences and the system's permission. Safe to call again, for example when the app
    /// comes back from iOS Settings.
    func refresh() async {
        authorization = await reminders.authorizationStatus
        do throws(PracticePreferencesError) {
            preferences = try await store.load()
            loadFailed = false
            if notice == .couldNotLoad { notice = nil }
        } catch {
            loadFailed = true
            notice = .couldNotLoad
        }
    }

    /// The reminders toggle. Turning on follows the permission state: allowed saves; not asked yet opens the
    /// pre-prompt; refused in iOS Settings does nothing here (the section explains and offers a way there).
    func setRemindersEnabled(_ enabled: Bool) async {
        guard canChangeReminders else { return }
        guard enabled else {
            await save { $0.remindersEnabled = false }
            return
        }
        authorization = await reminders.authorizationStatus
        switch authorization {
        case .authorized:
            await save { $0.remindersEnabled = true }
        case .notDetermined:
            prompt = makePrompt()
        case .denied:
            break
        }
    }

    /// Both pickers call this. A window with the same start and end would mean no quiet hours at all; that is
    /// not offered, so it is declined with a calm message and nothing changes.
    func setQuietHours(startHour: Int, endHour: Int) async {
        guard canChangeQuietHours else { return }
        let proposed = QuietHours(startHour: startHour, endHour: endHour)
        guard !proposed.isEmpty else {
            notice = .quietHoursNeedDifferentTimes
            return
        }
        guard proposed != preferences.quietHours else { return }
        await save { $0.quietHours = proposed }
    }

    func openIOSSettings() {
        openSystemSettings()
    }

    // MARK: Private

    private func makePrompt() -> NotificationsPromptViewModel {
        NotificationsPromptViewModel(
            reminders: reminders,
            preferences: store,
            onPracticeSettingsChanged: onPracticeSettingsChanged,
            onFinished: { [weak self] _ in
                guard let self else { return }
                prompt = nil
                Task { await self.refresh() }
            }
        )
    }

    private func save(_ change: (inout PracticePreferences) -> Void) async {
        var updated = preferences
        change(&updated)
        do throws(PracticePreferencesError) {
            try await store.save(updated)
        } catch {
            notice = .couldNotSave
            return
        }
        preferences = updated
        notice = nil
        await onPracticeSettingsChanged()
    }
}
