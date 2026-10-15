import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

/// The pieces RootView wires together for daily practice: rescheduling the reminders from what is stored, and
/// deciding whether the notification pre-prompt is due. Fake data only.
@MainActor
struct PracticeWiringTests {
    private typealias Support = SettingsPracticeSupport

    /// 2001-01-01 10:00 UTC, in a calendar fixed to UTC so quiet hours do not depend on the machine.
    private static let morning = Date(timeIntervalSinceReferenceDate: 10 * 3_600)
    private static let hour: TimeInterval = 3_600

    /// A log that cannot be read.
    private actor UnreadableLog: PracticeLogStore {
        func load() async throws(PracticeLogError) -> PracticeLog { throw .unreadable }
        func append(_ session: PracticeSession) async throws(PracticeLogError) { throw .unreadable }
        func erase() async throws(PracticeLogError) { throw .unreadable }
    }

    private func session(at date: Date) -> PracticeSession {
        PracticeSession(finishedAt: date, answered: 10)
    }

    private func rescheduler(
        language: CourseLanguage = .tamil,
        log: any PracticeLogStore,
        preferences: any PracticePreferencesStore = InMemoryPracticePreferencesStore(),
        reminders: FakeReminderScheduler,
        now: Date = PracticeWiringTests.morning.addingTimeInterval(PracticeWiringTests.hour / 2)
    ) -> ReminderRescheduler {
        ReminderRescheduler(
            language: language,
            log: log,
            preferences: preferences,
            reminders: reminders,
            calculator: StreakCalculator(),
            now: { now },
            calendar: { Support.utcCalendar }
        )
    }

    // MARK: Rescheduling

    @Test func schedulesBothRemindersFromTheLastSessionAndMovesTheOneInQuietHours() async {
        let reminders = FakeReminderScheduler(status: .authorized)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))

        await rescheduler(log: log, reminders: reminders).reschedule()

        let plans = await reminders.scheduledPlans
        #expect(plans.count == 1)
        let fireDates = plans.first?.reminders.map(\.fireDate)
        // 20 hours later is 06:00, inside the default quiet hours (22:00 to 08:00): it moves to 21:30 the evening
        // before. 23 hours later is 09:00 and stays.
        #expect(fireDates == [11.5, 23].map { Self.morning.addingTimeInterval($0 * Self.hour) })
        #expect(await reminders.cancelAllCount == 0)
    }

    @Test func namesTheStreakAndTheCourseLanguageAndNothingElse() async throws {
        let reminders = FakeReminderScheduler(status: .authorized)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))

        await rescheduler(language: .telugu, log: log, reminders: reminders).reschedule()

        let first = try #require(await reminders.scheduledPlans.first?.reminders.first)
        #expect(first.title == "1 day streak")
        #expect(first.body.contains("Telugu"))
        #expect(!first.body.contains("Tamil"))
    }

    @Test func usesTheStoredQuietHours() async {
        let reminders = FakeReminderScheduler(status: .authorized)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))
        let preferences = InMemoryPracticePreferencesStore(initial: PracticePreferences(quietHours: .none))

        await rescheduler(log: log, preferences: preferences, reminders: reminders).reschedule()

        let fireDates = await reminders.scheduledPlans.first?.reminders.map(\.fireDate)
        #expect(fireDates == [20, 23].map { Self.morning.addingTimeInterval($0 * Self.hour) })
    }

    @Test func cancelsEverythingWhenRemindersAreOff() async {
        let reminders = FakeReminderScheduler(status: .authorized)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))
        let preferences = InMemoryPracticePreferencesStore(initial: PracticePreferences(remindersEnabled: false))

        await rescheduler(log: log, preferences: preferences, reminders: reminders).reschedule()

        #expect(await reminders.cancelAllCount == 1)
        #expect(await reminders.scheduledPlans.isEmpty)
    }

    @Test(arguments: [ReminderAuthorization.denied, .notDetermined])
    func cancelsEverythingWhenTheSystemDoesNotAllowNotifications(status: ReminderAuthorization) async {
        let reminders = FakeReminderScheduler(status: status)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))

        await rescheduler(log: log, reminders: reminders).reschedule()

        #expect(await reminders.cancelAllCount == 1)
        #expect(await reminders.scheduledPlans.isEmpty)
    }

    @Test func cancelsEverythingWhenTheCourseHasNoFinishedSession() async {
        // A new learner, or the log after Reset progress.
        let reminders = FakeReminderScheduler(status: .authorized)

        await rescheduler(log: InMemoryPracticeLogStore(), reminders: reminders).reschedule()

        #expect(await reminders.cancelAllCount == 1)
        #expect(await reminders.scheduledPlans.isEmpty)
    }

    @Test func cancelsEverythingWhenEitherFileCannotBeRead() async {
        let reminders = FakeReminderScheduler(status: .authorized)
        let readableLog = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))
        let brokenPreferences = Support.StubPreferencesStore(loadError: .corrupt)

        await rescheduler(log: UnreadableLog(), reminders: reminders).reschedule()
        await rescheduler(log: readableLog, preferences: brokenPreferences, reminders: reminders).reschedule()

        #expect(await reminders.cancelAllCount == 2)
        #expect(await reminders.scheduledPlans.isEmpty)
    }

    @Test func aStreakThatAlreadyLapsedSchedulesNothingInThePast() async {
        let reminders = FakeReminderScheduler(status: .authorized)
        let log = InMemoryPracticeLogStore(initial: PracticeLog(sessions: [session(at: Self.morning)]))
        let threeDaysLater = Self.morning.addingTimeInterval(72 * Self.hour)

        await rescheduler(log: log, reminders: reminders, now: threeDaysLater).reschedule()

        let plan = await reminders.scheduledPlans.first
        #expect(plan?.isEmpty == true)
    }

    // MARK: Finished sessions across both courses, and the pre-prompt

    private func services(
        tamil: [PracticeSession] = [],
        telugu: [PracticeSession] = [],
        preferences: any PracticePreferencesStore = InMemoryPracticePreferencesStore(),
        status: ReminderAuthorization = .notDetermined
    ) -> PracticeServices {
        let tamilLog = InMemoryPracticeLogStore(initial: PracticeLog(sessions: tamil))
        let teluguLog = InMemoryPracticeLogStore(initial: PracticeLog(sessions: telugu))
        return PracticeServices(
            preferences: preferences,
            reminders: FakeReminderScheduler(status: status),
            logs: { language in
                switch language {
                case .tamil: tamilLog
                case .telugu: teluguLog
                }
            }
        )
    }

    @Test func countsFinishedSessionsInBothCourses() async {
        let one = session(at: Self.morning)
        let both = services(tamil: [one], telugu: [one, one])

        #expect(await both.finishedSessionCount() == 3)
    }

    @Test func anUnreadableLogCountsAsNone() async {
        let practice = PracticeServices(logs: { _ in UnreadableLog() })

        #expect(await practice.finishedSessionCount() == 0)
    }

    @Test func offersThePromptAfterTheVeryFirstFinishedSessionInEitherCourse() async {
        let afterTamil = services(tamil: [session(at: Self.morning)])
        let afterTelugu = services(telugu: [session(at: Self.morning)])

        #expect(await afterTamil.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) != nil)
        #expect(await afterTelugu.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) != nil)
    }

    @Test func doesNotOfferThePromptBeforeOrAfterTheFirstSessionAcrossBothCourses() async {
        let none = services()
        let second = services(tamil: [session(at: Self.morning)], telugu: [session(at: Self.morning)])

        #expect(await none.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
        #expect(await second.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
    }

    @Test func doesNotOfferThePromptTwiceOrWhenThereIsNothingToAsk() async {
        let asked = InMemoryPracticePreferencesStore(initial: PracticePreferences(hasAskedForNotifications: true))
        let alreadyAsked = services(tamil: [session(at: Self.morning)], preferences: asked)
        let allowed = services(tamil: [session(at: Self.morning)], status: .authorized)
        let refused = services(tamil: [session(at: Self.morning)], status: .denied)
        let unreadable = services(
            tamil: [session(at: Self.morning)],
            preferences: Support.StubPreferencesStore(loadError: .corrupt)
        )

        #expect(await alreadyAsked.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
        #expect(await allowed.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
        #expect(await refused.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
        #expect(await unreadable.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
    }

    @Test func notNowClosesThePromptAndItIsNotOfferedAgain() async throws {
        let preferences = InMemoryPracticePreferencesStore()
        let practice = services(tamil: [session(at: Self.morning)], preferences: preferences)
        let closed = ClosedFlag()

        let prompt = try #require(await practice.notificationsPromptIfDue(
            onPracticeSettingsChanged: {},
            onFinished: { closed.value = true }
        ))
        await prompt.notNow()

        #expect(closed.value)
        #expect(try await preferences.load().hasAskedForNotifications)
        #expect(await practice.notificationsPromptIfDue(onPracticeSettingsChanged: {}, onFinished: {}) == nil)
    }

    // MARK: One daily goal for the session end

    @Test func theSessionEndUsesTheGoalItWasGiven() async throws {
        let now = Self.morning
        let model = SessionViewModel(
            scenario: PreviewCatalog.scenario,
            dependencies: AppDependencies(
                catalog: PreviewCatalog.catalog,
                language: .tamil,
                store: InMemoryProgressStore(),
                scheduler: SM2Scheduler(),
                now: { now }
            ),
            random: .seeded(3),
            practiceLog: InMemoryPracticeLogStore(),
            calendar: Support.utcCalendar,
            streakCalculator: StreakCalculator(dailyGoal: 1)
        )
        await model.start()
        for _ in 0..<2 {
            guard case .session(.asking(let question)) = model.screen else { break }
            model.choose(try #require(question.options.first { $0.kind == .canonical }).id)
            model.advance()
        }
        await model.waitForPendingSaves()

        guard case .recorded(let outcome) = model.practiceState else {
            Issue.record("The chapter was not recorded")
            return
        }
        #expect(outcome.dailyGoal == 1)
        #expect(outcome.goalJustMet)
    }

    @MainActor
    private final class ClosedFlag {
        var value = false
    }
}
