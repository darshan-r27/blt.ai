import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

// The exam screen's state (DECISIONS 041). Fake `zz` items only; lessons come from `PreviewCatalog.lesson`.

private let examDate = Date(timeIntervalSince1970: 2_000_000)

/// A store whose writes always fail, to prove the result is still shown.
private actor FailingExamStore: ExamResultStore {
    func load() async throws(ExamResultStoreError) -> [ExamAttempt] { [] }
    func append(_ attempt: ExamAttempt) async throws(ExamResultStoreError) { throw .writeFailed }
    func erase() async throws(ExamResultStoreError) {}
}

private func paper(levels: [Int?]) -> ExamPaper {
    let items = PreviewCatalog.lesson("zz-exam", title: "zz Exam", level: nil).items
    let sources = levels.enumerated().map { index, level in
        // Four fake items exist per lesson; reuse them with fresh ids so each question is distinct.
        let base = items[index % items.count]
        let item = Item(
            id: ItemID(rawValue: "zz-q\(index)"),
            scenarioID: base.scenarioID,
            sourcePrompt: "zz prompt \(index)",
            register: .neutral,
            addressee: .any,
            canonical: "zz canonical \(index)",
            acceptedAnswers: ["zz canonical \(index)", "zz alt a \(index)", "zz alt b \(index)"],
            registerVariant: nil,
            distractors: ["zz wrong a", "zz wrong b", "zz wrong c"],
            tokens: base.tokens,
            note: nil,
            reviewStatus: .unreviewed
        )
        return ExamQuestionSource(item: item, level: level)
    }
    return ExamPaper(sources: sources)
}

@MainActor
private func makeModel(
    _ paper: ExamPaper,
    results: any ExamResultStore = InMemoryExamResultStore()
) -> ExamViewModel {
    ExamViewModel(
        paper: paper,
        language: .telugu,
        results: results,
        now: { examDate },
        random: .seeded(7)
    )
}

/// Answers the question on screen with its canonical option, or with a wrong one.
@MainActor
private func answer(_ model: ExamViewModel, right: Bool) {
    guard let question = model.question else { return }
    let wanted: AnswerOption.Kind = right ? .canonical : .distractor
    if let option = question.options.first(where: { $0.kind == wanted }) {
        model.choose(option.id)
    }
}

private func storedAttempts(_ store: InMemoryExamResultStore, after model: ExamViewModel) async -> [ExamAttempt] {
    await model.waitForSave()
    return (try? await store.load()) ?? []
}

@MainActor
struct ExamViewModelTests {
    @Test func startsOnTheIntroAndBeginShowsTheFirstQuestion() {
        let model = makeModel(paper(levels: [1, 1, 2, 2]))
        #expect(model.phase == .intro)
        #expect(model.question == nil)
        model.begin()
        #expect(model.phase == .asking)
        #expect(model.position == 1)
        #expect(model.total == 4)
        #expect(model.question != nil)
    }

    @Test func eachAnswerMovesStraightOnWithNoFeedbackAndNoWayBack() {
        let model = makeModel(paper(levels: [1, 1, 2, 2]))
        model.begin()
        answer(model, right: true)
        #expect(model.phase == .asking)
        #expect(model.position == 2)
        answer(model, right: false)
        #expect(model.position == 3)
        #expect(model.result == nil)
    }

    @Test func answeringEverythingRightPassesAndStoresOneAttemptOfNumbersOnly() async {
        let store = InMemoryExamResultStore()
        let model = makeModel(paper(levels: [1, 1, 2, 2]), results: store)
        model.begin()
        for _ in 0..<4 { answer(model, right: true) }
        #expect(model.phase == .finished)
        #expect(model.result?.passed == true)
        #expect(model.weakLevels.isEmpty)
        let attempts = await storedAttempts(store, after: model)
        #expect(attempts.count == 1)
        #expect(attempts.first?.correct == 4)
        #expect(attempts.first?.total == 4)
        #expect(attempts.first?.passed == true)
        #expect(attempts.first?.date == examDate)
        #expect(attempts.first?.levels.map(\.level) == [1, 2])
    }

    @Test func endingEarlyCountsUnansweredQuestionsAsWrongAfterConfirming() async {
        let store = InMemoryExamResultStore()
        let model = makeModel(paper(levels: [1, 1, 2, 2]), results: store)
        model.begin()
        answer(model, right: true)
        model.requestEnd()
        #expect(model.isConfirmingEnd)
        #expect(model.phase == .asking)
        model.cancelEnd()
        #expect(model.phase == .asking)
        model.requestEnd()
        model.confirmEnd()
        #expect(model.phase == .finished)
        #expect(model.result?.correct == 1)
        #expect(model.result?.total == 4)
        #expect(model.result?.passed == false)
        let attempts = await storedAttempts(store, after: model)
        #expect(attempts.first?.correct == 1)
    }

    @Test func onlyLevelsBelowThePassMarkAreCalledWeak() {
        // Level 1 all right, level 2 all wrong.
        let questions = paper(levels: [1, 1, 2, 2])
        let model = makeModel(questions)
        model.begin()
        while let question = model.question {
            let level = questions.sources.first { $0.item.id == question.item.id }?.level
            answer(model, right: level == 1)
        }
        #expect(model.weakLevels == [2])
    }

    @Test func aFailedSaveStillShowsTheResultAndSaysSo() async {
        let model = makeModel(paper(levels: [1, 1]), results: FailingExamStore())
        model.begin()
        for _ in 0..<2 { answer(model, right: true) }
        await model.waitForSave()
        #expect(model.phase == .finished)
        #expect(model.result != nil)
        #expect(model.saveFailed)
    }

    @Test func aPaperThatCannotBeBuiltDoesNotStartAShortExam() {
        // An item with too few options cannot become a four-option question.
        let bad = Item(
            id: ItemID(rawValue: "zz-bad"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz bad",
            register: .neutral,
            addressee: .any,
            canonical: "zz canonical",
            acceptedAnswers: ["zz canonical", "zz b", "zz c"],
            registerVariant: nil,
            distractors: ["zz only one"],
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
        let model = makeModel(ExamPaper(sources: [ExamQuestionSource(item: bad, level: 1)]))
        model.begin()
        #expect(model.startFailed)
        #expect(model.phase == .intro)
    }

    @Test func passMarkInQuestionsRoundsUp() {
        #expect(makeModel(paper(levels: Array(repeating: 1, count: 100))).correctNeededToPass == 75)
        #expect(makeModel(paper(levels: Array(repeating: 1, count: 10))).correctNeededToPass == 8)
        #expect(makeModel(paper(levels: Array(repeating: 1, count: 4))).correctNeededToPass == 3)
    }

    @Test func theStatementSaysRecognitionNotSpeech() {
        let text = ExamViewModel.recognitionStatement(for: .telugu)
        #expect(text.contains("Telugu"))
        #expect(text.contains("does not show that you can say it"))
    }
}
