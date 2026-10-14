import BLTDesign
import BLTProgress
import Foundation

/// What recording one finished chapter changed, for the summary screen: the streak before and after, whether
/// this chapter met the daily goal, and what the learner is working towards next.
struct PracticeOutcome: Sendable, Equatable {
    let finishedAt: Date
    let previousCount: Int
    let newCount: Int
    /// True only for the chapter that takes today from below the daily goal to the goal.
    let goalJustMet: Bool
    let freezesLeft: Int
    let daysUntilNextFreeze: Int?
    /// 7, 30, 50 or 100 when this chapter crossed one of them, otherwise `nil`.
    let milestoneDays: Int?
    let chaptersToday: Int
    let dailyGoal: Int
    /// The summary after this chapter, for the week strip.
    let summary: StreakSummary

    /// `before` and `after` are summaries of the log without and with the chapter, at the same moment.
    init(finishedAt: Date, before: StreakSummary, after: StreakSummary) {
        self.finishedAt = finishedAt
        self.previousCount = before.currentStreak
        self.newCount = after.currentStreak
        self.goalJustMet = !before.goalMet && after.goalMet
        self.freezesLeft = after.freezesAvailable
        self.daysUntilNextFreeze = after.daysUntilNextFreeze
        self.milestoneDays = StreakMilestone.reached(previousCount: before.currentStreak, count: after.currentStreak)
        self.chaptersToday = after.chaptersToday
        self.dailyGoal = after.dailyGoal
        self.summary = after
    }
}
