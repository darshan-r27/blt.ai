import BLTCore
import BLTProgress
import Foundation
import Testing

struct ReminderSchedulerFakeTests {
    private func reminder(_ slot: ReminderSlot, at seconds: TimeInterval) -> PlannedReminder {
        PlannedReminder(slot: slot, fireDate: Date(timeIntervalSince1970: seconds), title: "t", body: "b")
    }

    private func plan(_ first: TimeInterval, _ second: TimeInterval) -> ReminderPlan {
        ReminderPlan(reminders: [reminder(.first, at: first), reminder(.second, at: second)])
    }

    @Test func recordsEveryPlanAndHoldsTheLatestOne() async {
        let fake = FakeReminderScheduler()
        await fake.schedule(plan(100, 200))
        #expect(await fake.pendingReminders().map(\.identifier) == ["ai.blt.reminder.first", "ai.blt.reminder.second"])
        #expect(await fake.scheduledPlans.count == 1)
    }

    @Test func aNewPlanReplacesTheOldOneInsteadOfAddingToIt() async {
        let fake = FakeReminderScheduler()
        await fake.schedule(plan(100, 200))
        await fake.schedule(plan(300, 400))
        let pending = await fake.pendingReminders()
        #expect(pending.count == 2)
        #expect(pending.map(\.fireDate) == [Date(timeIntervalSince1970: 300), Date(timeIntervalSince1970: 400)])
        #expect(await fake.scheduledPlans.count == 2)
    }

    @Test func aSmallerPlanClearsTheSlotItLeavesOut() async {
        let fake = FakeReminderScheduler()
        await fake.schedule(plan(100, 200))
        await fake.schedule(ReminderPlan(reminders: [reminder(.second, at: 500)]))
        #expect(await fake.pendingReminders().map(\.slot) == [.second])
        await fake.schedule(.empty)
        #expect(await fake.pendingReminders().isEmpty)
    }

    @Test func cancelAllRemovesEverythingAndCountsTheCall() async {
        let fake = FakeReminderScheduler()
        await fake.schedule(plan(100, 200))
        await fake.cancelAll()
        #expect(await fake.pendingReminders().isEmpty)
        #expect(await fake.cancelAllCount == 1)
    }

    @Test func nothingIsScheduledWithoutPermission() async {
        let fake = FakeReminderScheduler(status: .denied)
        await fake.schedule(plan(100, 200))
        #expect(await fake.pendingReminders().isEmpty)
        #expect(await fake.scheduledPlans.count == 1)
    }

    @Test func askingForPermissionMovesFromNotDeterminedToAuthorized() async {
        let fake = FakeReminderScheduler(status: .notDetermined, grantsPermissionWhenAsked: true)
        #expect(await fake.authorizationStatus == .notDetermined)
        #expect(await fake.requestAuthorization())
        #expect(await fake.authorizationStatus == .authorized)
        #expect(await fake.authorizationRequestCount == 1)
    }

    @Test func aRefusedRequestLeavesPermissionDenied() async {
        let fake = FakeReminderScheduler(status: .notDetermined, grantsPermissionWhenAsked: false)
        #expect(await fake.requestAuthorization() == false)
        #expect(await fake.authorizationStatus == .denied)
    }

    @Test func aPlannerPlanCanBeScheduledThroughTheProtocol() async {
        let scheduler: any ReminderScheduling = FakeReminderScheduler()
        let planned = ReminderPlanner().plan(
            lastSessionFinish: Date(timeIntervalSince1970: 1_800_000_000),
            now: Date(timeIntervalSince1970: 1_800_000_000),
            calendar: Calendar(identifier: .gregorian),
            quietHours: .none,
            context: ReminderContext(language: .tamil, streakLength: 3)
        )
        await scheduler.schedule(planned)
        #expect(await scheduler.pendingReminders() == planned.reminders)
    }
}
