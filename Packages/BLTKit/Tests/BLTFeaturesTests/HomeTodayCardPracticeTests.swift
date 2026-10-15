import BLTCatalog
import BLTCore
import BLTDesign
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

// The Today card on Home: chapters done, the next one, goal met, and nothing to practise. Fake `zz` text only.

private func streak(chaptersToday: Int, goal: Int = 2) -> StreakSummary {
    StreakSummary(
        currentStreak: 4,
        longestStreak: 4,
        freezesAvailable: 1,
        daysUntilNextFreeze: 3,
        chaptersToday: chaptersToday,
        dailyGoal: goal,
        goalDays: 0,
        lastSessionAt: nil,
        deadline: nil,
        practisedDays: [],
        goalMetDays: [],
        frozenDays: []
    )
}

private let lesson = ScenarioSummary(
    scenario: PreviewCatalog.lesson("zz-a", title: "zz Lesson A", level: nil),
    snapshot: .empty
)

struct HomeTodayCardPracticeTests {
    @Test func noChaptersDoneStartsWithChapterOne() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 0), nextLesson: lesson)
        #expect(card.heading == "Today: 0 of 2 chapters")
        #expect(card.chapters.map(\.isDone) == [false, false])
        #expect(card.nextChapter?.number == 1)
        #expect(card.goalMet == false)
        #expect(card.canStart)
        #expect(card.note == nil)
    }

    @Test func oneChapterDoneMakesChapterTwoTheNext() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 1), nextLesson: lesson)
        #expect(card.heading == "Today: 1 of 2 chapters")
        #expect(card.chapters.map(\.isDone) == [true, false])
        #expect(card.chapters.map(\.isNext) == [false, true])
        #expect(card.accessibilityLabel == "Today: 1 of 2 chapters, next: chapter 2, zz Lesson A")
    }

    @Test func bothChaptersDoneMeansTheGoalIsMetAndNoChapterIsNext() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 2), nextLesson: lesson)
        #expect(card.goalMet)
        #expect(card.chapters.map(\.isDone) == [true, true])
        #expect(card.nextChapter == nil)
        #expect(card.heading == "Today: 2 of 2 chapters")
        #expect(card.note == "Daily goal met. You can keep practising if you like.")
        #expect(card.accessibilityLabel.hasPrefix("Today: 2 of 2 chapters, daily goal met"))
        #expect(card.canStart)
    }

    @Test func extraChaptersNeverShowMoreThanTheGoal() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 5), nextLesson: lesson)
        #expect(card.done == 2)
        #expect(card.chapters.count == 2)
    }

    @Test func nothingToPractiseSaysSoCalmlyAndCannotStart() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 0), nextLesson: nil)
        #expect(card.hasNothingToPractise)
        #expect(card.canStart == false)
        #expect(card.nextChapter == nil)
        #expect(card.note == "There is nothing to practise right now. New reviews will show up here.")
    }

    @Test func nothingToPractiseAfterTheGoalIsMetIsStillCalm() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 2), nextLesson: nil)
        #expect(card.note == "Daily goal met. There is nothing more to practise right now.")
    }

    @Test func aDifferentGoalChangesTheRowCount() {
        let card = HomeTodayCard(summary: streak(chaptersToday: 1, goal: 3), nextLesson: lesson)
        #expect(card.chapters.count == 3)
        #expect(card.heading == "Today: 1 of 3 chapters")
    }

    @Test func freezeLinesAreCalmAndNeverRed() {
        let held = streak(chaptersToday: 0)
        #expect(HomeViewModel.freezeLine(for: held) == "1 freeze left, next in 3 days")
        #expect(HomeViewModel.freezeLine(for: .empty()) == "No freezes left")
    }
}
