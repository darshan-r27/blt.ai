import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

struct MachineTestGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

struct SessionMachineTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func item(_ number: Int, withVariant: Bool = false) -> Item {
        Item(
            id: ItemID(rawValue: "zz-\(number)"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz prompt \(number)",
            register: withVariant ? .respectful : .neutral,
            addressee: .any,
            canonical: "zz canonical \(number)",
            acceptedAnswers: ["zz canonical \(number)", "zz b", "zz c"],
            registerVariant: withVariant ? "zz variant \(number)" : nil,
            distractors: withVariant
                ? ["zz w1 \(number)", "zz w2 \(number)"]
                : ["zz w1 \(number)", "zz w2 \(number)", "zz w3 \(number)"],
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
    }

    private func items(_ count: Int, withVariant: Bool = false) -> [Item] {
        (1...count).map { item($0, withVariant: withVariant) }
    }

    private func makeMachine(_ items: [Item], seed: UInt64 = 7) -> SessionMachine {
        var rng = MachineTestGenerator(state: seed)
        return SessionMachine(items: items, using: &rng)
    }

    private func currentQuestion(_ machine: SessionMachine) throws -> Question {
        guard case .asking(let question) = machine.state else {
            throw MachineTestError.notAsking
        }
        return question
    }

    private func optionID(_ question: Question, _ kind: AnswerOption.Kind) throws -> Int {
        try #require(question.options.first { $0.kind == kind }).id
    }

    private func answer(
        _ machine: inout SessionMachine,
        _ kind: AnswerOption.Kind,
        rng: inout MachineTestGenerator
    ) throws -> AttemptRecord? {
        let id = try optionID(currentQuestion(machine), kind)
        return machine.choose(id, at: now, using: &rng)
    }

    /// Plays to the end, answering each presentation with `policy(itemNumber, presentationIndexForThatItem)`.
    /// Returns the presented item IDs in order and every record produced.
    private func play(
        _ machine: inout SessionMachine,
        seed: UInt64 = 99,
        policy: (String, Int) -> AnswerOption.Kind
    ) throws -> (presented: [String], records: [AttemptRecord]) {
        var rng = MachineTestGenerator(state: seed)
        var presented: [String] = []
        var seenCounts: [String: Int] = [:]
        var records: [AttemptRecord] = []
        while case .asking(let question) = machine.state {
            let id = question.item.id.rawValue
            presented.append(id)
            let count = seenCounts[id, default: 0]
            seenCounts[id] = count + 1
            if let record = try answer(&machine, policy(id, count), rng: &rng) {
                records.append(record)
            }
            machine.advance(using: &rng)
        }
        return (presented, records)
    }

    // MARK: Start

    @Test func startsAskingTheFirstItem() throws {
        let machine = makeMachine(items(3))
        let question = try currentQuestion(machine)
        #expect(question.item.id.rawValue == "zz-1")
        #expect(question.options.count == 4)
        #expect(machine.requeuedCount == 0)
    }

    @Test func emptyPlanStartsFinishedWithZeroCounts() {
        let machine = makeMachine([])
        #expect(machine.state == .finished(SessionResult(correctCount: 0, wrongRegisterCount: 0, wrongCount: 0)))
        if case .finished(let result) = machine.state {
            #expect(result.total == 0)
        }
    }

    @Test func itemsThatFailToBuildAreSkipped() throws {
        var broken = item(2)
        broken = Item(
            id: broken.id,
            scenarioID: broken.scenarioID,
            sourcePrompt: broken.sourcePrompt,
            register: broken.register,
            addressee: broken.addressee,
            canonical: broken.canonical,
            acceptedAnswers: broken.acceptedAnswers,
            registerVariant: nil,
            distractors: ["zz only one"],
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
        var started = makeMachine([item(1), broken, item(3)])
        let result = try play(&started) { _, _ in .canonical }
        #expect(result.presented == ["zz-1", "zz-3"])

        let allBroken = makeMachine([broken])
        #expect(allBroken.state == .finished(SessionResult(correctCount: 0, wrongRegisterCount: 0, wrongCount: 0)))
    }

    // MARK: Legal transitions

    @Test func chooseMovesToFeedbackAndAdvanceMovesOn() throws {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine(items(2))
        let first = try currentQuestion(machine)
        let correctID = try optionID(first, .canonical)

        let record = machine.choose(correctID, at: now, using: &rng)
        #expect(record == AttemptRecord(itemID: first.item.id, outcome: .correct, date: now))
        #expect(machine.state == .feedback(first, chosen: correctID, verdict: .correct))

        machine.advance(using: &rng)
        let second = try currentQuestion(machine)
        #expect(second.item.id.rawValue == "zz-2")
    }

    @Test func lastAdvanceFinishes() throws {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine(items(1))
        _ = try answer(&machine, .canonical, rng: &rng)
        machine.advance(using: &rng)
        #expect(machine.state == .finished(SessionResult(correctCount: 1, wrongRegisterCount: 0, wrongCount: 0)))
    }

    @Test func allThreeVerdictsAreReachableWithMatchingOutcomes() throws {
        var rng = MachineTestGenerator(state: 5)
        var machine = makeMachine(items(3, withVariant: true))
        var verdicts: [Verdict] = []
        var outcomes: [Outcome] = []
        for kind in [AnswerOption.Kind.canonical, .registerVariant, .distractor] {
            let record = try answer(&machine, kind, rng: &rng)
            guard case .feedback(_, _, let verdict) = machine.state else {
                throw MachineTestError.notFeedback
            }
            verdicts.append(verdict)
            outcomes.append(try #require(record).outcome)
            machine.advance(using: &rng)
        }
        #expect(verdicts == [.correct, .wrongRegister(correct: "zz canonical 2"), .notQuite(correct: "zz canonical 3")])
        #expect(outcomes == [.correct, .wrongRegister, .wrong])
    }

    // MARK: Illegal transitions are no-ops

    @Test func unknownOptionIDIsANoOp() throws {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine(items(2))
        let before = machine.state
        #expect(machine.choose(99, at: now, using: &rng) == nil)
        #expect(machine.choose(-1, at: now, using: &rng) == nil)
        #expect(machine.state == before)
        #expect(machine.requeuedCount == 0)
        // The item is still answerable afterwards, so the failed attempts recorded nothing.
        #expect(try answer(&machine, .canonical, rng: &rng) != nil)
    }

    @Test func chooseInFeedbackIsANoOp() throws {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine(items(2))
        _ = try answer(&machine, .distractor, rng: &rng)
        let before = machine.state
        let requeuedBefore = machine.requeuedCount
        #expect(machine.choose(0, at: now, using: &rng) == nil)
        #expect(machine.state == before)
        #expect(machine.requeuedCount == requeuedBefore)
    }

    @Test func chooseInFinishedIsANoOp() {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine([])
        let before = machine.state
        #expect(machine.choose(0, at: now, using: &rng) == nil)
        #expect(machine.state == before)
    }

    @Test func advanceInAskingIsANoOp() throws {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine(items(2))
        let before = machine.state
        machine.advance(using: &rng)
        #expect(machine.state == before)
    }

    @Test func advanceInFinishedIsANoOp() {
        var rng = MachineTestGenerator(state: 1)
        var machine = makeMachine([])
        let before = machine.state
        machine.advance(using: &rng)
        #expect(machine.state == before)
    }

    // MARK: Counts and determinism

    @Test func resultCountsFirstAttemptsOnly() throws {
        var machine = makeMachine(items(3, withVariant: true))
        let run = try play(&machine) { id, count in
            switch (id, count) {
            case ("zz-1", 0): .distractor // first attempt wrong, then fixed on the requeue
            case ("zz-2", _): .registerVariant
            default: .canonical
            }
        }
        #expect(run.presented == ["zz-1", "zz-2", "zz-3", "zz-1"])
        #expect(run.records.count == 3)
        let expected = SessionResult(correctCount: 1, wrongRegisterCount: 1, wrongCount: 1)
        #expect(machine.state == .finished(expected))
        #expect(expected.total == 3)
    }

    @Test func sameSeedsGiveIdenticalSessions() throws {
        var first = makeMachine(items(5, withVariant: true), seed: 21)
        var second = makeMachine(items(5, withVariant: true), seed: 21)
        let policy: (String, Int) -> AnswerOption.Kind = { id, count in
            id == "zz-3" && count < 2 ? .distractor : .canonical
        }
        let one = try play(&first, seed: 8, policy: policy)
        let two = try play(&second, seed: 8, policy: policy)
        #expect(one.presented == two.presented)
        #expect(one.records == two.records)
        #expect(first.state == second.state)
    }
}

extension SessionMachineTests {
    // MARK: Requeue

    @Test func wrongAnswerIsRequeuedThreePositionsLater() throws {
        var machine = makeMachine(items(5))
        let run = try play(&machine) { id, count in
            id == "zz-1" && count == 0 ? .distractor : .canonical
        }
        #expect(run.presented == ["zz-1", "zz-2", "zz-3", "zz-1", "zz-4", "zz-5"])
        #expect(machine.requeuedCount == 1)
    }

    @Test func requeueGoesToTheEndWhenFewerRemain() throws {
        var machine = makeMachine(items(2))
        let run = try play(&machine) { id, count in
            id == "zz-1" && count == 0 ? .distractor : .canonical
        }
        #expect(run.presented == ["zz-1", "zz-2", "zz-1"])

        var single = makeMachine(items(1))
        let singleRun = try play(&single) { _, count in count == 0 ? .distractor : .canonical }
        #expect(singleRun.presented == ["zz-1", "zz-1"])
    }

    @Test func requeueHappensAtMostTwicePerItem() throws {
        var machine = makeMachine(items(5))
        let run = try play(&machine) { id, _ in id == "zz-1" ? .distractor : .canonical }
        #expect(run.presented == ["zz-1", "zz-2", "zz-3", "zz-1", "zz-4", "zz-5", "zz-1"])
        #expect(run.presented.filter { $0 == "zz-1" }.count == 3)
        #expect(machine.requeuedCount == 2)
        #expect(machine.state == .finished(SessionResult(correctCount: 4, wrongRegisterCount: 0, wrongCount: 1)))
    }

    @Test func requeuedPresentationsRecordNothing() throws {
        var machine = makeMachine(items(3))
        let run = try play(&machine) { id, count in
            id == "zz-2" && count < 2 ? .distractor : .canonical
        }
        #expect(run.presented.count == 5)
        #expect(run.records.map(\.itemID.rawValue) == ["zz-1", "zz-2", "zz-3"])
        #expect(run.records.map(\.outcome) == [.correct, .wrong, .correct])
    }

    @Test func wrongRegisterIsNotRequeued() throws {
        var machine = makeMachine(items(3, withVariant: true))
        let run = try play(&machine) { _, _ in .registerVariant }
        #expect(run.presented == ["zz-1", "zz-2", "zz-3"])
        #expect(machine.requeuedCount == 0)
        #expect(machine.state == .finished(SessionResult(correctCount: 0, wrongRegisterCount: 3, wrongCount: 0)))
    }

    @Test func requeuedQuestionKeepsTheItemAndOptionsButIsRebuilt() throws {
        var rng = MachineTestGenerator(state: 11)
        var machine = makeMachine(items(4, withVariant: true))
        let original = try currentQuestion(machine)
        _ = try answer(&machine, .distractor, rng: &rng)
        machine.advance(using: &rng)
        machine.advance(using: &rng) // no-op in asking: still on the second item
        _ = try answer(&machine, .canonical, rng: &rng)
        machine.advance(using: &rng)
        let third = try currentQuestion(machine)
        _ = try answer(&machine, .canonical, rng: &rng)
        machine.advance(using: &rng)
        let again = try currentQuestion(machine)
        #expect(third.item.id.rawValue == "zz-3")
        #expect(again.item == original.item)
        #expect(Set(again.options.map(\.text)) == Set(original.options.map(\.text)))
        #expect(again.options.count == 4)
    }
}

private enum MachineTestError: Error {
    case notAsking
    case notFeedback
}
