import BLTDesign

/// One level on Home: its lessons in course order, and completion across all of their items.
///
/// Completion reuses `ScenarioSummary`'s rule (DECISIONS 033): an item counts only when its latest outcome is
/// correct. The level's figures are the lessons' counts added together, so a lesson with more items weighs more.
struct HomeLevelSection: Equatable, Identifiable {
    let number: Int
    let title: String
    /// Sorted by `level.position`, then by id.
    let lessons: [ScenarioSummary]

    var id: Int { number }

    var totalCount: Int {
        lessons.reduce(0) { $0 + $1.totalCount }
    }

    var completedCount: Int {
        lessons.reduce(0) { $0 + $1.completedCount }
    }

    /// Whole-number percent, rounded down so 100 means every item is complete; 0 when there are no items.
    var completionPercent: Int {
        totalCount == 0 ? 0 : completedCount * 100 / totalCount
    }

    /// Every item of every lesson is complete. A level with no items is never complete.
    var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    /// The visible header text: "Level 1: Survival".
    var headerTitle: String {
        "Level \(number): \(title)"
    }

    /// What VoiceOver reads as the header's label, for example "Level 1, Survival".
    var accessibilityLabel: String {
        "Level \(number), \(title)"
    }

    /// What VoiceOver reads as the header's value, for example "40 percent complete, expanded".
    func accessibilityValue(isExpanded: Bool) -> String {
        let completion = CompletionBar.accessibilityValue(forPercent: completionPercent)
        return "\(completion), \(isExpanded ? "expanded" : "collapsed")"
    }
}
