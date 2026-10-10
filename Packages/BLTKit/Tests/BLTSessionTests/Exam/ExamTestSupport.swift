import BLTCatalog
import BLTCore
import BLTSession

/// Fake `zz` fixtures and a scripted player for the exam tests.
enum ExamTestSupport {
    static func item(_ number: Int, register: Register = .neutral) -> Item {
        let hasVariant = register != .neutral
        return Item(
            id: ItemID(rawValue: "zz-\(number)"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz prompt \(number)",
            register: register,
            addressee: .any,
            canonical: "zz canonical \(number)",
            acceptedAnswers: ["zz canonical \(number)", "zz b \(number)", "zz c \(number)"],
            registerVariant: hasVariant ? "zz variant \(number)" : nil,
            distractors: Array(["zz w1 \(number)", "zz w2 \(number)", "zz w3 \(number)"].prefix(hasVariant ? 2 : 3)),
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
    }

    /// The number in an id made by `item(_:)`.
    static func number(of id: ItemID) -> Int {
        Int(id.rawValue.dropFirst(3)) ?? -1
    }

    static func graded(_ number: Int, level: Int?, correct: Bool) -> ExamGradedQuestion {
        ExamGradedQuestion(source: ExamQuestionSource(item: item(number), level: level), isCorrect: correct)
    }

    /// One question per entry; item numbers follow the position in `levels`.
    static func paper(levels: [Int?]) -> ExamPaper {
        ExamPaper(sources: levels.enumerated().map { ExamQuestionSource(item: item($0.offset), level: $0.element) })
    }

    static func machine(_ paper: ExamPaper, seed: UInt64 = 1) -> ExamMachine? {
        var rng = SeededGenerator(state: seed)
        return ExamMachine(paper: paper, using: &rng)
    }

    /// Answers every question, canonical where `isRight` says so and a distractor otherwise, then returns the result.
    static func play(_ machine: inout ExamMachine, isRight: (ItemID) -> Bool) -> ExamResult? {
        while let question = machine.currentQuestion {
            let wanted: AnswerOption.Kind = isRight(question.item.id) ? .canonical : .distractor
            guard let option = question.options.first(where: { $0.kind == wanted }) else { return nil }
            machine.answer(option.id)
            machine.advance()
        }
        return machine.result
    }
}
