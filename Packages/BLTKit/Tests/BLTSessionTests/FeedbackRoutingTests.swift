import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

/// Which feedback an answer leads to, and whether the item is asked again. These rules used to be checked
/// by tapping each kind of option in a UI test (DECISIONS 045); here the machine is driven directly.
struct FeedbackRoutingTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func item(_ number: Int, withVariant: Bool) -> Item {
        Item(
            id: ItemID(rawValue: "zz-route-\(number)"),
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

    /// A machine over `count` items, the first with a register variant. Returns the question on screen.
    private func start(count: Int) throws -> (SessionMachine, Question) {
        var rng = MachineTestGenerator(state: 21)
        let machine = SessionMachine(items: (1...count).map { item($0, withVariant: $0 == 1) }, using: &rng)
        guard case .asking(let question) = machine.state else { throw RoutingError.notAsking }
        return (machine, question)
    }

    private func optionID(_ question: Question, _ kind: AnswerOption.Kind) throws -> Int {
        try #require(question.options.first { $0.kind == kind }).id
    }

    @Test func eachKindOfOptionHasItsOwnVerdict() throws {
        var rng = MachineTestGenerator(state: 3)
        let question = try #require(QuestionBuilder().makeQuestion(for: item(1, withVariant: true), using: &rng))

        #expect(question.verdict(for: try optionID(question, .canonical)) == .correct)
        let variantID = try optionID(question, .registerVariant)
        let distractorID = try optionID(question, .distractor)
        #expect(question.verdict(for: variantID) == .wrongRegister(correct: "zz canonical 1"))
        #expect(question.verdict(for: distractorID) == .notQuite(correct: "zz canonical 1"))
    }

    @Test func anOptionThatIsNotOnTheQuestionHasNoVerdictAndChangesNothing() throws {
        let started = try start(count: 2)
        var machine = started.0
        let question = started.1
        var rng = MachineTestGenerator(state: 4)
        let unknownID = (question.options.map(\.id).max() ?? 0) + 1

        #expect(question.verdict(for: unknownID) == nil)
        let attempt = machine.choose(unknownID, at: now, using: &rng)

        #expect(attempt == nil)
        #expect(machine.state == .asking(question))
    }

    @Test func aMissedItemIsAskedAgainButAnOtherRegisterAnswerIsNot() throws {
        // Two items, the first with a register variant. Answer each item's first presentation wrongly in the
        // way that is possible for it, then finish, and count how many questions were asked.
        var rng = MachineTestGenerator(state: 5)
        var machine = try start(count: 2).0
        var asked: [ItemID] = []
        // A session of two items cannot ask more than four questions here; the bound stops a runaway loop.
        for _ in 0..<10 {
            guard case .asking(let question) = machine.state else { break }
            let isRegisterItem = question.item.registerVariant != nil
            let isReturn = asked.contains(question.item.id)
            asked.append(question.item.id)
            let kind: AnswerOption.Kind = isReturn ? .canonical : (isRegisterItem ? .registerVariant : .distractor)
            _ = machine.choose(try optionID(question, kind), at: now, using: &rng)
            machine.advance(using: &rng)
        }

        // The register item is asked once (not requeued); the plain item is missed once, so asked twice.
        #expect(asked.filter { $0 == ItemID(rawValue: "zz-route-1") }.count == 1)
        #expect(asked.filter { $0 == ItemID(rawValue: "zz-route-2") }.count == 2)
        guard case .finished(let result) = machine.state else {
            Issue.record("expected the session to finish")
            return
        }
        #expect(result == SessionResult(correctCount: 0, wrongRegisterCount: 1, wrongCount: 1))
    }
}

private enum RoutingError: Error {
    case notAsking
}
