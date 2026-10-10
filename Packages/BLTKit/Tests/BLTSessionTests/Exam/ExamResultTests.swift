import BLTCatalog
import BLTCore
import BLTSession
import Testing

struct ExamResultTests {
    private func result(correct: Int, of total: Int) -> ExamResult {
        let source = ExamQuestionSource(item: ExamTestSupport.item(0), level: 1)
        return ExamResult(graded: (0..<total).map { ExamGradedQuestion(source: source, isCorrect: $0 < correct) })
    }

    @Test func emptyPaperDoesNotPassAndDoesNotDivideByZero() {
        let empty = ExamResult(graded: [])
        #expect(empty.total == 0)
        #expect(empty.correct == 0)
        #expect(empty.percent == 0)
        #expect(!empty.passed)
        #expect(empty.weakestLevels().isEmpty)
        #expect(empty.missedItemIDs.isEmpty)
    }

    @Test func passMarkBoundaries() {
        #expect(result(correct: 75, of: 100).passed)
        #expect(!result(correct: 74, of: 100).passed)
        #expect(result(correct: 3, of: 4).passed)
        #expect(!result(correct: 2, of: 3).passed)
        #expect(result(correct: 100, of: 100).passed)
        #expect(!result(correct: 0, of: 100).passed)
    }

    @Test func percentRoundsDown() {
        #expect(result(correct: 2, of: 3).percent == 66)
        #expect(result(correct: 74, of: 100).percent == 74)
        #expect(result(correct: 100, of: 100).percent == 100)
    }

    @Test func breakdownGroupsByLevelAndKeepsUnnumberedQuestionsApart() {
        let graded = [
            ExamTestSupport.graded(0, level: 1, correct: true),
            ExamTestSupport.graded(1, level: 1, correct: false),
            ExamTestSupport.graded(2, level: 2, correct: true),
            ExamTestSupport.graded(3, level: nil, correct: false)
        ]
        let breakdown = ExamResult(graded: graded).byLevel
        #expect(breakdown[1] == ExamLevelScore(correct: 1, total: 2))
        #expect(breakdown[2] == ExamLevelScore(correct: 1, total: 1))
        #expect(breakdown[Int?.none] == ExamLevelScore(correct: 0, total: 1))
        #expect(breakdown.count == 3)
    }

    @Test func weakestLevelsOrdersByRatioThenLowerNumberAndSkipsNilLevel() {
        // Level 1: 1/2, level 2: 0/2, level 3: 1/2, level 4: 2/2, unnumbered: 0/3 (never eligible).
        let plan: [(Int?, [Bool])] = [
            (1, [true, false]), (2, [false, false]), (3, [true, false]), (4, [true, true]), (nil, [false, false, false])
        ]
        var graded: [ExamGradedQuestion] = []
        for (level, flags) in plan {
            for flag in flags {
                graded.append(ExamTestSupport.graded(graded.count, level: level, correct: flag))
            }
        }
        let outcome = ExamResult(graded: graded)
        #expect(outcome.weakestLevels(limit: 2) == [2, 1])
        #expect(outcome.weakestLevels(limit: 3) == [2, 1, 3])
        #expect(outcome.weakestLevels() == [2, 1])
        #expect(outcome.weakestLevels(limit: 10) == [2, 1, 3, 4])
        #expect(outcome.weakestLevels(limit: 0).isEmpty)
    }

    @Test func weakestLevelsComparesFractionsNotCounts() {
        // Level 1: 1/10 is weaker than level 2: 1/2 even though both have one correct.
        var graded = (0..<10).map { ExamTestSupport.graded($0, level: 1, correct: $0 == 0) }
        graded.append(ExamTestSupport.graded(20, level: 2, correct: true))
        graded.append(ExamTestSupport.graded(21, level: 2, correct: false))
        #expect(ExamResult(graded: graded).weakestLevels(limit: 1) == [1])
    }
}
