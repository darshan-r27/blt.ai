import BLTDesign
import Testing

struct StreakMilestoneTests {
    @Test func milestonesAreSevenThirtyFiftyAndOneHundred() {
        #expect(StreakMilestone.days == [7, 30, 50, 100])
        #expect([7, 30, 50, 100].allSatisfy(StreakMilestone.isMilestone))
        #expect(![0, 1, 6, 8, 29, 31, 49, 51, 99, 101].contains(where: StreakMilestone.isMilestone))
    }

    @Test func reachedWhenTheStreakStepsOntoAMilestone() {
        #expect(StreakMilestone.reached(previousCount: 6, count: 7) == 7)
        #expect(StreakMilestone.reached(previousCount: 29, count: 30) == 30)
        #expect(StreakMilestone.reached(previousCount: 49, count: 50) == 50)
        #expect(StreakMilestone.reached(previousCount: 99, count: 100) == 100)
    }

    @Test func notReachedBetweenMilestonesOrWhenRepeated() {
        #expect(StreakMilestone.reached(previousCount: 7, count: 8) == nil)
        #expect(StreakMilestone.reached(previousCount: 12, count: 13) == nil)
        #expect(StreakMilestone.reached(previousCount: 0, count: 0) == nil)
        // A second session on the same day leaves the count at a milestone: no second celebration.
        #expect(StreakMilestone.reached(previousCount: 7, count: 7) == nil)
        // A streak that fell does not celebrate.
        #expect(StreakMilestone.reached(previousCount: 30, count: 1) == nil)
    }

    @Test func aJumpOverSeveralMilestonesReportsTheHighest() {
        #expect(StreakMilestone.reached(previousCount: 5, count: 31) == 30)
        #expect(StreakMilestone.reached(previousCount: 0, count: 200) == 100)
    }

    @Test func nextMilestone() {
        #expect(StreakMilestone.next(after: 0) == 7)
        #expect(StreakMilestone.next(after: 7) == 30)
        #expect(StreakMilestone.next(after: 29) == 30)
        #expect(StreakMilestone.next(after: 99) == 100)
        #expect(StreakMilestone.next(after: 100) == nil)
    }

    @Test func celebrationStyle() {
        #expect(StreakCelebrationStyle(previousCount: 12, count: 13) == .burst)
        #expect(StreakCelebrationStyle(previousCount: 0, count: 1) == .burst)
        #expect(StreakCelebrationStyle(previousCount: 6, count: 7) == .milestone(days: 7))
        #expect(StreakCelebrationStyle(previousCount: 99, count: 100) == .milestone(days: 100))
        #expect(StreakCelebrationStyle(previousCount: 13, count: 13) == .quiet)
        #expect(StreakCelebrationStyle(previousCount: 7, count: 7) == .quiet)
    }

    @Test func milestoneDaysOnlyForMilestoneStyle() {
        #expect(StreakCelebrationStyle.milestone(days: 30).milestoneDays == 30)
        #expect(StreakCelebrationStyle.burst.milestoneDays == nil)
        #expect(StreakCelebrationStyle.quiet.milestoneDays == nil)
    }
}
