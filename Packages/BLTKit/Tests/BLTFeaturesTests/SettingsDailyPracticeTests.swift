import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// The Daily practice section of Settings: toggle, quiet hours, goal row, denied state, and Reset.
@MainActor
struct SettingsDailyPracticeTests {
    private typealias Support = SettingsPracticeSupport

    // MARK: Defaults and the goal row

    @Test func startsWithDefaultsAndTheFixedGoal() async {
        let settings = Support.settings()
        await settings.practice.refresh()

        #expect(settings.practice.preferences == .standard)
        #expect(settings.practice.quietStartHour == 22)
        #expect(settings.practice.quietEndHour == 8)
        #expect(settings.practice.dailyGoal == 2)
        #expect(settings.practice.dailyGoalText == "2 chapters a day")
    }

    @Test func hoursAreLabelledForTheCalendarLocale() {
        let practice = Support.settings().practice
        let label = practice.hourLabel(22)
        #expect(label.contains("10"))
        #expect(label.localizedCaseInsensitiveContains("pm"))
    }

    // MARK: The reminders toggle

    @Test func toggleShowsOffUntilTheSystemAllowsNotifications() async {
        let settings = Support.settings(reminders: FakeReminderScheduler(status: .notDetermined))
        await settings.practice.refresh()
        #expect(settings.practice.preferences.remindersEnabled)
        #expect(!settings.practice.remindersAreOn)
    }

    @Test func turningOffSavesAndNotifiesTheOwner() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()
        #expect(settings.practice.remindersAreOn)

        await settings.practice.setRemindersEnabled(false)

        #expect(!settings.practice.remindersAreOn)
        let loaded1 = try await store.load()
        #expect(loaded1.remindersEnabled == false)
        #expect(await counter.calls == 1)
    }

    @Test func turningOnWhenAllowedSavesAndNotifies() async throws {
        let store = InMemoryPracticePreferencesStore(initial: PracticePreferences(remindersEnabled: false))
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()
        #expect(!settings.practice.remindersAreOn)

        await settings.practice.setRemindersEnabled(true)

        #expect(settings.practice.remindersAreOn)
        let loaded2 = try await store.load()
        #expect(loaded2.remindersEnabled)
        #expect(await counter.calls == 1)
        #expect(settings.practice.prompt == nil)
    }

    @Test func turningOnBeforePermissionOpensThePrePromptAndAsksNothingYet() async {
        let scheduler = FakeReminderScheduler(status: .notDetermined)
        let counter = Support.ChangeCounter()
        let settings = Support.settings(reminders: scheduler, onChanged: { await counter.record() })
        await settings.practice.refresh()

        await settings.practice.setRemindersEnabled(true)

        #expect(settings.practice.prompt != nil)
        #expect(await scheduler.authorizationRequestCount == 0)
        #expect(await counter.calls == 0)
    }

    @Test func allowingInThePrePromptTurnsRemindersOnAndClosesIt() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let settings = Support.settings(
            preferences: store,
            reminders: FakeReminderScheduler(status: .notDetermined),
            onChanged: { await counter.record() }
        )
        await settings.practice.refresh()
        await settings.practice.setRemindersEnabled(true)

        await settings.practice.prompt?.allow()
        await settings.practice.refresh()

        #expect(settings.practice.prompt == nil)
        #expect(settings.practice.remindersAreOn)
        let loaded3 = try await store.load()
        #expect(loaded3.hasAskedForNotifications)
        #expect(await counter.calls == 1)
    }

    // MARK: Denied

    @Test func deniedStateExplainsCalmlyAndOffersIOSSettings() async {
        var opened = 0
        let settings = Support.settings(
            reminders: FakeReminderScheduler(status: .denied),
            openSettings: { opened += 1 }
        )
        await settings.practice.refresh()

        #expect(settings.practice.notificationsAreDenied)
        #expect(!settings.practice.canChangeReminders)
        #expect(!settings.practice.remindersAreOn)
        let text = DailyPracticeSettingsModel.deniedExplanation
        #expect(text.contains("iOS Settings"))
        #expect(!text.contains("!"))

        settings.practice.openIOSSettings()
        #expect(opened == 1)
    }

    @Test func turningOnWhileDeniedChangesNothing() async throws {
        let store = InMemoryPracticePreferencesStore(initial: PracticePreferences(remindersEnabled: false))
        let counter = Support.ChangeCounter()
        let settings = Support.settings(
            preferences: store,
            reminders: FakeReminderScheduler(status: .denied),
            onChanged: { await counter.record() }
        )
        await settings.practice.refresh()

        await settings.practice.setRemindersEnabled(true)

        let loaded4 = try await store.load()
        #expect(loaded4.remindersEnabled == false)
        #expect(settings.practice.prompt == nil)
        #expect(await counter.calls == 0)
    }

    // MARK: Quiet hours

    @Test func changingQuietHoursSavesAndNotifies() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()

        await settings.practice.setQuietHours(startHour: 21, endHour: 7)

        let loaded5 = try await store.load()
        #expect(loaded5.quietHours == QuietHours(startHour: 21, endHour: 7))
        #expect(settings.practice.quietStartHour == 21)
        #expect(settings.practice.quietEndHour == 7)
        #expect(settings.practice.noticeMessage == nil)
        #expect(await counter.calls == 1)
    }

    @Test func anEmptyWindowIsDeclinedCalmlyAndNothingChanges() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()

        await settings.practice.setQuietHours(startHour: 9, endHour: 9)

        #expect(settings.practice.notice == .quietHoursNeedDifferentTimes)
        let message = try #require(settings.practice.noticeMessage)
        #expect(message.contains("unchanged"))
        #expect(!message.contains("!"))
        let loaded6 = try await store.load()
        #expect(loaded6.quietHours == .standard)
        #expect(settings.practice.quietStartHour == 22)
        #expect(await counter.calls == 0)
    }

    @Test func choosingTheSameHoursAgainDoesNotSaveOrNotify() async {
        let store = Support.StubPreferencesStore()
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()

        await settings.practice.setQuietHours(startHour: 22, endHour: 8)

        #expect(await store.saveCount == 0)
        #expect(await counter.calls == 0)
    }

    // MARK: Failures

    @Test func aFailedSaveIsReportedAndLeavesTheScreenAsStored() async {
        let store = Support.StubPreferencesStore(saveError: .writeFailed)
        let counter = Support.ChangeCounter()
        let settings = Support.settings(preferences: store, onChanged: { await counter.record() })
        await settings.practice.refresh()

        await settings.practice.setQuietHours(startHour: 21, endHour: 7)

        #expect(settings.practice.notice == .couldNotSave)
        #expect(settings.practice.quietStartHour == 22)
        #expect(await counter.calls == 0)
    }

    @Test func anUnreadableFileDisablesTheControlsAndSaysSo() async {
        let store = Support.StubPreferencesStore(loadError: .corrupt)
        let settings = Support.settings(preferences: store)
        await settings.practice.refresh()

        #expect(settings.practice.loadFailed)
        #expect(settings.practice.notice == .couldNotLoad)
        #expect(!settings.practice.canChangeReminders)
        #expect(!settings.practice.canChangeQuietHours)

        await settings.practice.setQuietHours(startHour: 21, endHour: 7)
        #expect(await store.saveCount == 0)
    }

    // MARK: Reset progress

    @Test func resetErasesThisCoursesPracticeLogAndKeepsPreferences() async throws {
        let log = Support.StubPracticeLogStore(log: Support.oneSession())
        let preferences = InMemoryPracticePreferencesStore(
            initial: PracticePreferences(remindersEnabled: false, quietHours: QuietHours(startHour: 21, endHour: 7))
        )
        let settings = Support.settings(preferences: preferences, practiceLog: log)

        await settings.confirmReset()

        #expect(settings.resetOutcome == .succeeded)
        #expect(await log.eraseCount == 1)
        let loaded7 = try await log.load()
        #expect(loaded7 == .empty)
        let loaded8 = try await preferences.load()
        #expect(loaded8.quietHours == QuietHours(startHour: 21, endHour: 7))
        let loaded9 = try await preferences.load()
        #expect(loaded9.remindersEnabled == false)
    }

    @Test func resetReportsAFailureToEraseThePracticeLog() async {
        let log = Support.StubPracticeLogStore(log: Support.oneSession(), eraseError: .eraseFailed)
        var didReset = false
        let settings = SettingsViewModel(
            dependencies: Support.dependencies(),
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
            profileName: "zz Sample",
            onDidReset: { didReset = true },
            practiceLog: log
        )

        await settings.confirmReset()

        #expect(settings.resetOutcome == .failed(.eraseFailed))
        #expect(!didReset)
    }

    @Test func resetConfirmationMentionsTheStreak() {
        #expect(Support.settings().resetMessage.contains("streak"))
    }
}
