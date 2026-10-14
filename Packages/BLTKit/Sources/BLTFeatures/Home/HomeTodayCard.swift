import BLTDesign
import BLTProgress

/// What the Today card on Home shows, from the day's streak summary and the lesson that would be practised
/// next. Pure: no clock, no disk.
///
/// A chapter is one practice session (plan.md "Daily practice"). Starting one opens `nextLesson` exactly as the
/// Continue card does, so the card carries no session logic of its own.
struct HomeTodayCard: Equatable {
    let chapters: [HomeTodayChapter]
    /// Chapters finished today, never more than `goal`.
    let done: Int
    let goal: Int
    let goalMet: Bool
    /// The lesson a tap opens; `nil` when there is nothing to practise.
    let nextLesson: ScenarioSummary?

    init(summary: StreakSummary, nextLesson: ScenarioSummary?) {
        let goal = max(summary.dailyGoal, 1)
        let done = min(max(summary.chaptersToday, 0), goal)
        self.goal = goal
        self.done = done
        self.goalMet = summary.goalMet
        self.nextLesson = nextLesson
        self.chapters = (1...goal).map { number in
            HomeTodayChapter(number: number, isDone: number <= done, isNext: nextLesson != nil && number == done + 1)
        }
    }

    /// The first chapter not yet done, if there is something to practise.
    var nextChapter: HomeTodayChapter? {
        chapters.first(where: \.isNext)
    }

    /// Nothing to start: every lesson is complete (or the catalog is empty).
    var hasNothingToPractise: Bool {
        nextLesson == nil
    }

    /// Whether a tap starts a session. After the goal is met a learner may still practise more.
    var canStart: Bool {
        nextLesson != nil
    }

    /// "Today: 1 of 2 chapters". Shown as the card's heading; the goal-met mark carries the rest.
    var heading: String {
        StreakLabels.today(chaptersDone: done, goal: goal).components(separatedBy: ",")[0]
    }

    /// The calm line under the chapters, or `nil` when the rows say it all.
    var note: String? {
        switch (hasNothingToPractise, goalMet) {
        case (true, true): "Daily goal met. There is nothing more to practise right now."
        case (true, false): "There is nothing to practise right now. New reviews will show up here."
        case (false, true): "Daily goal met. You can keep practising if you like."
        case (false, false): nil
        }
    }

    /// One VoiceOver sentence for the card: "Today: 1 of 2 chapters, next: chapter 2, zz Lesson".
    var accessibilityLabel: String {
        var parts = [StreakLabels.today(chaptersDone: done, goal: goal)]
        if let next = nextChapter, let lesson = nextLesson {
            parts.append("next: chapter \(next.number), \(lesson.title)")
        } else if let note {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }
}
