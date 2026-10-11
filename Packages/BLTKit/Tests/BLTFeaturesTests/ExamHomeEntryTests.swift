import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

@testable import BLTFeatures

// The final-exam entry on Home, and Reset clearing exam results (DECISIONS 041). Fake `zz` text only.

private let moment = Date(timeIntervalSince1970: 1_000_000)

private func levelOne(_ id: String) -> Scenario {
    PreviewCatalog.lesson(id, title: "zz \(id)", level: Level(number: 1, title: "zz Level", position: 1))
}

private func completed(_ scenario: Scenario) -> [ReviewState] {
    scenario.items.map {
        ReviewState(
            itemID: $0.id,
            repetitions: 1,
            intervalDays: 1,
            easeFactor: 2.5,
            due: moment,
            lastOutcome: .correct,
            lastReviewed: moment
        )
    }
}

private func snapshot(_ states: [ReviewState]) -> ProgressSnapshot {
    ProgressSnapshot(reviews: Dictionary(uniqueKeysWithValues: states.map { ($0.itemID, $0) }), attempts: [])
}

private let samplePaper = ExamPaper(sources: [
    ExamQuestionSource(item: PreviewCatalog.lesson("zz-p", title: "zz", level: nil).items[0], level: 1)
])

private func attempt(correct: Int, total: Int) -> ExamAttempt {
    ExamAttempt(
        date: moment,
        correct: correct,
        total: total,
        passed: correct * 100 >= 75 * total,
        levels: [BLTProgress.ExamLevelScore(level: 1, correct: correct, total: total)]
    )
}

@MainActor
private func loaded(
    scenarios: [Scenario],
    states: [ReviewState] = [],
    paper: ExamPaper? = samplePaper,
    results: any ExamResultStore = InMemoryExamResultStore()
) async -> HomeViewModel {
    let model = HomeViewModel(dependencies: AppDependencies(
        catalog: Catalog(scenarios: scenarios, issues: []),
        language: .telugu,
        store: InMemoryProgressStore(initial: snapshot(states)),
        scheduler: SM2Scheduler(),
        now: { moment },
        examResults: results,
        examPaper: paper
    ))
    await model.load()
    return model
}

@MainActor
struct ExamHomeEntryTests {
    @Test func noPaperMeansNoEntry() async {
        let one = levelOne("zz-a")
        let model = await loaded(scenarios: [one], states: completed(one), paper: nil)
        #expect(model.examEntry == nil)
    }

    @Test func anEmptyPaperMeansNoEntry() async {
        let one = levelOne("zz-a")
        let model = await loaded(scenarios: [one], states: completed(one), paper: ExamPaper(sources: []))
        #expect(model.examEntry == nil)
    }

    @Test func theEntryIsLockedUntilEveryLevelIsComplete() async {
        let one = levelOne("zz-a")
        let two = PreviewCatalog.lesson("zz-b", title: "zz b", level: Level(number: 2, title: "zz L2", position: 1))
        let partly = await loaded(scenarios: [one, two], states: completed(one))
        #expect(partly.examEntry?.isUnlocked == false)
        #expect(partly.examEntry?.summary.contains("Finish every level") == true)
        let all = await loaded(scenarios: [one, two], states: completed(one) + completed(two))
        #expect(all.examEntry?.isUnlocked == true)
    }

    @Test func aCourseWithNoLevelledLessonsNeverUnlocksTheExam() async {
        let loose = PreviewCatalog.lesson("zz-loose", title: "zz loose", level: nil)
        let model = await loaded(scenarios: [loose], states: completed(loose))
        #expect(model.examEntry?.isUnlocked == false)
    }

    @Test func theBestAttemptIsShown() async {
        let one = levelOne("zz-a")
        let store = InMemoryExamResultStore(
            initial: [attempt(correct: 60, total: 100), attempt(correct: 82, total: 100)]
        )
        let model = await loaded(scenarios: [one], states: completed(one), results: store)
        #expect(model.examEntry?.bestLine == "Best: 82 of 100, passed")
    }

    @Test func aFailedAttemptIsDescribedAsNotPassedYet() async {
        let one = levelOne("zz-a")
        let store = InMemoryExamResultStore(initial: [attempt(correct: 60, total: 100)])
        let model = await loaded(scenarios: [one], states: completed(one), results: store)
        #expect(model.examEntry?.bestLine == "Best: 60 of 100, not passed yet")
    }

    @Test func resetOnHomeClearsExamResultsToo() async {
        let one = levelOne("zz-a")
        let store = InMemoryExamResultStore(initial: [attempt(correct: 90, total: 100)])
        let model = await loaded(scenarios: [one], states: completed(one), results: store)
        await model.confirmReset()
        #expect(((try? await store.load()) ?? [attempt(correct: 0, total: 0)]).isEmpty)
        #expect(model.examEntry?.bestLine == nil)
    }
}

@MainActor
struct ExamSettingsResetTests {
    @Test func resetProgressInSettingsClearsExamResultsToo() async {
        let one = levelOne("zz-a")
        let results = InMemoryExamResultStore(initial: [attempt(correct: 90, total: 100)])
        let dependencies = AppDependencies(
            catalog: Catalog(scenarios: [one], issues: []),
            language: .telugu,
            store: InMemoryProgressStore(initial: snapshot(completed(one))),
            scheduler: SM2Scheduler(),
            now: { moment },
            examResults: results,
            examPaper: samplePaper
        )
        let model = SettingsViewModel(
            dependencies: dependencies,
            profileStore: InMemoryProfileStore(),
            profileName: "zz Sample"
        )
        model.requestReset()
        await model.confirmReset()
        #expect(model.resetOutcome == .succeeded)
        #expect(((try? await results.load()) ?? [attempt(correct: 0, total: 0)]).isEmpty)
    }
}
