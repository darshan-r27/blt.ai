import BLTCatalog
import BLTCore
import BLTSession
import Testing

struct ExamMachineTests {
    private typealias Support = ExamTestSupport

    @Test func emptyPaperIsFinishedAtOnceAndNotPassed() throws {
        let machine = try #require(Support.machine(ExamPaper(sources: [])))
        #expect(machine.isFinished)
        #expect(machine.total == 0)
        #expect(machine.currentQuestion == nil)
        let result = try #require(machine.result)
        #expect(!result.passed)
        #expect(result.total == 0)
        #expect(result.percent == 0)
    }

    @Test func allCorrectPassesWithFullMarks() throws {
        var machine = try #require(Support.machine(Support.paper(levels: Array(repeating: 1, count: 8))))
        let result = try #require(Support.play(&machine, isRight: { _ in true }))
        #expect(result.correct == 8)
        #expect(result.percent == 100)
        #expect(result.passed)
        #expect(result.missedItemIDs.isEmpty)
    }

    @Test func allWrongFails() throws {
        var machine = try #require(Support.machine(Support.paper(levels: Array(repeating: 1, count: 8))))
        let result = try #require(Support.play(&machine, isRight: { _ in false }))
        #expect(result.correct == 0)
        #expect(!result.passed)
        #expect(result.missedItemIDs.count == 8)
    }

    @Test func exactlySeventyFiveOfOneHundredPassesAndSeventyFourFails() throws {
        let paper = Support.paper(levels: (0..<100).map { $0 % 8 + 1 })
        var passing = try #require(Support.machine(paper))
        let passed = try #require(Support.play(&passing, isRight: { id in Support.number(of: id) < 75 }))
        #expect(passed.correct == 75)
        #expect(passed.passed)

        var failing = try #require(Support.machine(paper))
        let failed = try #require(Support.play(&failing, isRight: { id in Support.number(of: id) < 74 }))
        #expect(failed.correct == 74)
        #expect(!failed.passed)
    }

    @Test func threeOfFourPassesAndTwoOfThreeDoesNot() throws {
        var four = try #require(Support.machine(Support.paper(levels: [1, 1, 1, 1])))
        let threeOfFour = try #require(Support.play(&four, isRight: { $0.rawValue != "zz-0" }))
        #expect(threeOfFour.passed)

        var three = try #require(Support.machine(Support.paper(levels: [1, 1, 1])))
        let twoOfThree = try #require(Support.play(&three, isRight: { $0.rawValue != "zz-0" }))
        #expect(!twoOfThree.passed)
    }

    @Test func onlyTheCanonicalOptionScores() throws {
        // A respectful item has a register variant; choosing it must be wrong (DECISIONS 033).
        let source = ExamQuestionSource(item: Support.item(0, register: .respectful), level: 1)
        var variantMachine = try #require(Support.machine(ExamPaper(sources: [source])))
        let variant = try #require(variantMachine.currentQuestion?.options.first { $0.kind == .registerVariant })
        variantMachine.answer(variant.id)
        variantMachine.advance()
        #expect(try #require(variantMachine.result).correct == 0)

        var canonicalMachine = try #require(Support.machine(ExamPaper(sources: [source])))
        let canonical = try #require(canonicalMachine.currentQuestion?.options.first { $0.kind == .canonical })
        canonicalMachine.answer(canonical.id)
        canonicalMachine.advance()
        #expect(try #require(canonicalMachine.result).correct == 1)
    }

    @Test func finishEarlyCountsUnansweredAsWrong() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1, 1, 1, 1])))
        for _ in 0..<2 {
            let canonical = try #require(machine.currentQuestion?.options.first { $0.kind == .canonical })
            machine.answer(canonical.id)
            machine.advance()
        }
        #expect(machine.result == nil)
        machine.finish()
        #expect(machine.isFinished)
        #expect(machine.currentQuestion == nil)
        let result = try #require(machine.result)
        #expect(result.total == 4)
        #expect(result.correct == 2)
        #expect(!result.passed)
        #expect(result.missedItemIDs.count == 2)
    }

    @Test func secondAnswerToTheSameQuestionIsRejectedAndKeepsTheFirst() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1, 1])))
        let question = try #require(machine.currentQuestion)
        let wrong = try #require(question.options.first { $0.kind == .distractor })
        let right = try #require(question.options.first { $0.kind == .canonical })
        let outcome1 = machine.answer(wrong.id)
        #expect(outcome1 == .accepted)
        let outcome2 = machine.answer(right.id)
        #expect(outcome2 == .alreadyAnswered)
        machine.advance()
        machine.finish()
        #expect(try #require(machine.result).correct == 0)
    }

    @Test func answerAfterFinishIsRejected() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1, 1])))
        let option = try #require(machine.currentQuestion?.options.first)
        machine.finish()
        let outcome3 = machine.answer(option.id)
        #expect(outcome3 == .finished)
        #expect(try #require(machine.result).correct == 0)
    }

    @Test func unknownOptionIsRejected() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1])))
        let outcome4 = machine.answer(99)
        #expect(outcome4 == .unknownOption)
        #expect(!machine.currentIsAnswered)
    }

    @Test func movesOnlyForwardAndOnlyAfterAnAnswer() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1, 1, 1])))
        #expect(machine.currentIndex == 0)
        let outcome5 = machine.advance()
        #expect(!outcome5)
        #expect(machine.currentIndex == 0)

        let first = try #require(machine.currentQuestion)
        machine.answer(first.options[0].id)
        #expect(machine.answeredCount == 1)
        #expect(machine.remaining == 2)
        let outcome6 = machine.advance()
        #expect(outcome6)
        #expect(machine.currentIndex == 1)
        #expect(machine.currentQuestion != first)
        #expect(machine.currentQuestion?.id != first.id)
    }

    @Test func advancingPastTheLastQuestionEndsTheExam() throws {
        var machine = try #require(Support.machine(Support.paper(levels: [1, 2])))
        for _ in 0..<2 {
            let option = try #require(machine.currentQuestion?.options.first)
            machine.answer(option.id)
            machine.advance()
        }
        #expect(machine.isFinished)
        #expect(machine.currentIndex == 2)
        #expect(machine.remaining == 0)
        let outcome7 = machine.advance()
        #expect(!outcome7)
    }

    @Test func everyQuestionIsAskedOnceWithFourOptionsAndOneCanonical() throws {
        let paper = Support.paper(levels: Array(repeating: 1, count: 30))
        var machine = try #require(Support.machine(paper, seed: 7))
        var seen: [ItemID] = []
        while let question = machine.currentQuestion {
            seen.append(question.item.id)
            #expect(question.options.count == 4)
            #expect(question.options.filter { $0.kind == .canonical }.count == 1)
            machine.answer(question.options[0].id)
            machine.advance()
        }
        #expect(Set(seen) == Set(paper.sources.map(\.item.id)))
        #expect(seen.count == 30)
    }

    @Test func presentationOrderIsShuffledAndResultStaysInPaperOrder() throws {
        let paper = Support.paper(levels: Array(repeating: 1, count: 30))
        var machine = try #require(Support.machine(paper, seed: 3))
        var presented: [ItemID] = []
        while let question = machine.currentQuestion {
            presented.append(question.item.id)
            machine.answer(question.options[0].id)
            machine.advance()
        }
        let paperOrder = paper.sources.map(\.item.id)
        #expect(presented != paperOrder)
        // Everything wrong or right, the missed list follows the paper, not the order shown.
        var again = try #require(Support.machine(paper, seed: 3))
        let result = try #require(Support.play(&again, isRight: { _ in false }))
        #expect(result.missedItemIDs == paperOrder)
    }

    @Test func sameSeedGivesTheSameOrderAndOptions() throws {
        let paper = Support.paper(levels: Array(repeating: 1, count: 20))
        func questions(seed: UInt64) throws -> [Question] {
            var machine = try #require(Support.machine(paper, seed: seed))
            var shown: [Question] = []
            while let question = machine.currentQuestion {
                shown.append(question)
                machine.answer(question.options[0].id)
                machine.advance()
            }
            return shown
        }
        #expect(try questions(seed: 11) == questions(seed: 11))
        #expect(try questions(seed: 11) != questions(seed: 12))
    }

    @Test func aPaperWithAnUnbuildableItemIsRefusedNotShortened() {
        // Neutral item with one distractor gives two options, not four.
        let good = Support.item(0)
        let broken = Item(
            id: ItemID(rawValue: "zz-1"),
            scenarioID: good.scenarioID,
            sourcePrompt: good.sourcePrompt,
            register: .neutral,
            addressee: .any,
            canonical: "zz canonical 1",
            acceptedAnswers: ["zz canonical 1"],
            registerVariant: nil,
            distractors: ["zz w1"],
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
        let sources = [ExamQuestionSource(item: good, level: 1), ExamQuestionSource(item: broken, level: 1)]
        #expect(Support.machine(ExamPaper(sources: sources)) == nil)
    }

    @Test func twoLanguagePapersAreKeptApartByTheCaller() throws {
        let first = Support.paper(levels: [1, 1, 1, 1])
        let second = Support.paper(levels: [2, 2])
        var machineA = try #require(Support.machine(first))
        var machineB = try #require(Support.machine(second))
        let resultA = try #require(Support.play(&machineA, isRight: { _ in true }))
        let resultB = try #require(Support.play(&machineB, isRight: { _ in false }))
        #expect(resultA.total == 4 && resultA.passed)
        #expect(resultB.total == 2 && !resultB.passed)
    }
}
