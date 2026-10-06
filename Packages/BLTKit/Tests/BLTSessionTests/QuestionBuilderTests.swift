import BLTCatalog
import BLTCore
import BLTSession
import Testing

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

struct QuestionBuilderTests {
    private func item(register: Register, variant: String?, distractors: [String]) -> Item {
        Item(
            id: ItemID(rawValue: "zz-1"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz",
            register: register,
            addressee: .any,
            canonical: "zz canonical",
            acceptedAnswers: ["zz canonical", "zz b", "zz c"],
            registerVariant: variant,
            distractors: distractors,
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
    }

    private var respectfulItem: Item {
        item(register: .respectful, variant: "zz casual", distractors: ["zz w1", "zz w2"])
    }

    @Test func itemWithVariantYieldsFourOptionsOfDistinctKinds() throws {
        var rng = SeededGenerator(state: 1)
        let question = try #require(QuestionBuilder().makeQuestion(for: respectfulItem, using: &rng))
        #expect(question.options.count == 4)
        let kinds = question.options.map(\.kind)
        #expect(kinds.filter { $0 == .canonical }.count == 1)
        #expect(kinds.filter { $0 == .registerVariant }.count == 1)
        #expect(kinds.filter { $0 == .distractor }.count == 2)
    }

    @Test func neutralItemYieldsCanonicalPlusThreeDistractors() throws {
        var rng = SeededGenerator(state: 2)
        let neutral = item(register: .neutral, variant: nil, distractors: ["zz w1", "zz w2", "zz w3"])
        let question = try #require(QuestionBuilder().makeQuestion(for: neutral, using: &rng))
        #expect(question.options.filter { $0.kind == .registerVariant }.isEmpty)
        #expect(question.options.filter { $0.kind == .distractor }.count == 3)
    }

    @Test func sameSeedGivesSameOrder() throws {
        var first = SeededGenerator(state: 42)
        var second = SeededGenerator(state: 42)
        let one = try #require(QuestionBuilder().makeQuestion(for: respectfulItem, using: &first))
        let two = try #require(QuestionBuilder().makeQuestion(for: respectfulItem, using: &second))
        #expect(one.options == two.options)
    }

    @Test func returnsNilOnCollisionOrWrongCount() {
        var rng = SeededGenerator(state: 3)
        let builder = QuestionBuilder()
        let collision = item(register: .neutral, variant: nil, distractors: ["ZZ CANONICAL ", "zz w2", "zz w3"])
        let tooMany = item(register: .respectful, variant: "zz casual", distractors: ["zz w1", "zz w2", "zz w3"])
        let tooFew = item(register: .neutral, variant: nil, distractors: ["zz w1", "zz w2"])
        #expect(builder.makeQuestion(for: collision, using: &rng) == nil)
        #expect(builder.makeQuestion(for: tooMany, using: &rng) == nil)
        #expect(builder.makeQuestion(for: tooFew, using: &rng) == nil)
    }

    @Test func verdictFollowsTheChosenOption() throws {
        var rng = SeededGenerator(state: 4)
        let question = try #require(QuestionBuilder().makeQuestion(for: respectfulItem, using: &rng))

        func optionID(_ kind: AnswerOption.Kind) throws -> Int {
            try #require(question.options.first { $0.kind == kind }).id
        }

        #expect(question.verdict(for: try optionID(.canonical)) == .correct)
        #expect(question.verdict(for: try optionID(.registerVariant)) == .wrongRegister(correct: "zz canonical"))
        #expect(question.verdict(for: try optionID(.distractor)) == .notQuite(correct: "zz canonical"))
        #expect(question.verdict(for: 99) == nil)
    }
}
