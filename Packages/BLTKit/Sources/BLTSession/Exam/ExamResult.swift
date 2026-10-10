import BLTCore

/// The verdict on a finished exam. Built from the graded questions in paper order.
public struct ExamResult: Sendable, Equatable {
    public let graded: [ExamGradedQuestion]

    public init(graded: [ExamGradedQuestion]) {
        self.graded = graded
    }

    public var total: Int { graded.count }

    public var correct: Int { graded.filter(\.isCorrect).count }

    public var passed: Bool { ExamPaper.isPass(correct: correct, total: total) }

    /// Whole percent, rounded down. 0 for an empty paper.
    public var percent: Int { total == 0 ? 0 : correct * 100 / total }

    /// Counts per level. The `nil` key holds questions that belong to no single level.
    public var byLevel: [Int?: ExamLevelScore] {
        var counts: [Int?: ExamLevelScore] = [:]
        for question in graded {
            let before = counts[question.source.level] ?? ExamLevelScore(correct: 0, total: 0)
            counts[question.source.level] = ExamLevelScore(
                correct: before.correct + (question.isCorrect ? 1 : 0),
                total: before.total + 1
            )
        }
        return counts
    }

    /// Ids of the questions answered wrongly or not at all, in paper order.
    public var missedItemIDs: [ItemID] {
        graded.filter { !$0.isCorrect }.map { $0.source.item.id }
    }

    /// Up to `limit` numbered levels with the lowest share correct, weakest first. Ties go to the lower level
    /// number. Questions with no level number are not eligible. A level with full marks is still listed when
    /// fewer than `limit` other levels exist; the screen can filter on `byLevel` if it wants only real weaknesses.
    public func weakestLevels(limit: Int = 2) -> [Int] {
        guard limit > 0 else { return [] }
        let numbered: [(level: Int, score: ExamLevelScore)] = byLevel.compactMap { key, score in
            key.map { (level: $0, score: score) }
        }
        let ordered = numbered.sorted { lhs, rhs in
            // Compare the fractions by cross-multiplying, so no floating point is involved.
            let left = lhs.score.correct * rhs.score.total
            let right = rhs.score.correct * lhs.score.total
            return left != right ? left < right : lhs.level < rhs.level
        }
        return ordered.prefix(limit).map(\.level)
    }
}
