import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// The notification permission pre-prompt: when it may appear, and what Allow and Not now do.
@MainActor
struct NotificationsPromptTests {
    private typealias Support = SettingsPracticeSupport

    /// Records the outcomes the prompt reported to its owner.
    @MainActor
    private final class Finished {
        private(set) var outcomes: [NotificationsPromptViewModel.Outcome] = []
        func record(_ outcome: NotificationsPromptViewModel.Outcome) { outcomes.append(outcome) }
    }

    private func makePrompt(
        status: ReminderAuthorization = .notDetermined,
        grants: Bool = true,
        store: any PracticePreferencesStore = InMemoryPracticePreferencesStore(),
        counter: Support.ChangeCounter = Support.ChangeCounter(),
        finished: Finished = Finished()
    ) -> (NotificationsPromptViewModel, FakeReminderScheduler) {
        let scheduler = FakeReminderScheduler(status: status, grantsPermissionWhenAsked: grants)
        let model = NotificationsPromptViewModel(
            reminders: scheduler,
            preferences: store,
            onPracticeSettingsChanged: { await counter.record() },
            onFinished: { finished.record($0) }
        )
        return (model, scheduler)
    }

    // MARK: The rule

    @Test func asksAtTheEndOfTheFirstFinishedSession() {
        #expect(NotificationsPromptRule.shouldAsk(
            finishedSessionCount: 1, hasAskedBefore: false, authorization: .notDetermined
        ))
    }

    @Test func doesNotAskBeforeAnySessionHasFinished() {
        #expect(!NotificationsPromptRule.shouldAsk(
            finishedSessionCount: 0, hasAskedBefore: false, authorization: .notDetermined
        ))
    }

    @Test func doesNotAskAtLaterSessions() {
        for count in [2, 3, 50] {
            #expect(!NotificationsPromptRule.shouldAsk(
                finishedSessionCount: count, hasAskedBefore: false, authorization: .notDetermined
            ))
        }
    }

    @Test func doesNotAskTwice() {
        #expect(!NotificationsPromptRule.shouldAsk(
            finishedSessionCount: 1, hasAskedBefore: true, authorization: .notDetermined
        ))
    }

    @Test func doesNotAskOnceTheSystemHasAnAnswer() {
        for status in [ReminderAuthorization.authorized, .denied] {
            #expect(!NotificationsPromptRule.shouldAsk(
                finishedSessionCount: 1, hasAskedBefore: false, authorization: status
            ))
        }
    }

    // MARK: Wording

    @Test func reasonIsOneCalmLineWithoutUrgencyOrNames() {
        let reason = NotificationsPromptViewModel.reason
        #expect(reason.hasPrefix("Would you like a gentle reminder before your streak lapses?"))
        #expect(!reason.contains("!"))
        #expect(!reason.contains("\n"))
        #expect(!NotificationsPromptViewModel.detail.contains("!"))
    }

    // MARK: Allow

    @Test func allowAsksTheSystemSavesRemindersOnAndTellsTheOwner() async throws {
        let store = InMemoryPracticePreferencesStore(initial: PracticePreferences(remindersEnabled: false))
        let counter = Support.ChangeCounter()
        let finished = Finished()
        let (model, scheduler) = makePrompt(store: store, counter: counter, finished: finished)

        await model.allow()

        #expect(await scheduler.authorizationRequestCount == 1)
        let saved = try await store.load()
        #expect(saved.remindersEnabled)
        #expect(saved.hasAskedForNotifications)
        #expect(await counter.calls == 1)
        #expect(model.outcome == .allowed)
        #expect(finished.outcomes == [.allowed])
    }

    @Test func allowThatTheSystemRefusesSavesRemindersOffAndRemembersTheQuestion() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let finished = Finished()
        let (model, _) = makePrompt(grants: false, store: store, counter: counter, finished: finished)

        await model.allow()

        let saved = try await store.load()
        #expect(!saved.remindersEnabled)
        #expect(saved.hasAskedForNotifications)
        #expect(await counter.calls == 1)
        #expect(finished.outcomes == [.notGranted])
    }

    @Test func allowKeepsQuietHours() async throws {
        let custom = QuietHours(startHour: 21, endHour: 7)
        let store = InMemoryPracticePreferencesStore(initial: PracticePreferences(quietHours: custom))
        let (model, _) = makePrompt(store: store)

        await model.allow()

        let loaded1 = try await store.load()
        #expect(loaded1.quietHours == custom)
    }

    // MARK: Not now

    @Test func notNowAsksTheSystemNothingAndRemembersTheChoice() async throws {
        let store = InMemoryPracticePreferencesStore()
        let counter = Support.ChangeCounter()
        let finished = Finished()
        let (model, scheduler) = makePrompt(store: store, counter: counter, finished: finished)

        await model.notNow()

        #expect(await scheduler.authorizationRequestCount == 0)
        let saved = try await store.load()
        #expect(saved.hasAskedForNotifications)
        #expect(saved.remindersEnabled == PracticePreferences.standard.remindersEnabled)
        #expect(finished.outcomes == [.notNow])
        #expect(model.outcome == .notNow)
    }

    @Test func afterNotNowTheRuleNeverAsksAgain() async throws {
        let store = InMemoryPracticePreferencesStore()
        let (model, _) = makePrompt(store: store)
        await model.notNow()

        let asked = try await store.load().hasAskedForNotifications
        #expect(!NotificationsPromptRule.shouldAsk(
            finishedSessionCount: 1, hasAskedBefore: asked, authorization: .notDetermined
        ))
    }

    @Test func swipingThePromptAwayCountsAsNotNow() async throws {
        let store = InMemoryPracticePreferencesStore()
        let finished = Finished()
        let (model, scheduler) = makePrompt(store: store, finished: finished)

        await model.dismissed()

        #expect(await scheduler.authorizationRequestCount == 0)
        let loaded2 = try await store.load()
        #expect(loaded2.hasAskedForNotifications)
        #expect(finished.outcomes == [.notNow])
    }

    // MARK: Failures and repeats

    @Test func aFailedSaveKeepsThePromptOpenAndSaysSo() async {
        let store = Support.StubPreferencesStore(saveError: .writeFailed)
        let finished = Finished()
        let (model, _) = makePrompt(store: store, finished: finished)

        await model.notNow()

        #expect(model.saveFailed)
        #expect(model.outcome == nil)
        #expect(finished.outcomes.isEmpty)
    }

    @Test func swipingAwayStillClosesWhenTheChoiceCannotBeSaved() async {
        let store = Support.StubPreferencesStore(saveError: .writeFailed)
        let finished = Finished()
        let (model, _) = makePrompt(store: store, finished: finished)

        await model.dismissed()

        #expect(finished.outcomes == [.notNow])
    }

    @Test func anAnsweredPromptIgnoresFurtherTaps() async {
        let counter = Support.ChangeCounter()
        let finished = Finished()
        let (model, scheduler) = makePrompt(counter: counter, finished: finished)

        await model.allow()
        await model.allow()
        await model.notNow()

        #expect(await scheduler.authorizationRequestCount == 1)
        #expect(await counter.calls == 1)
        #expect(finished.outcomes == [.allowed])
    }
}
