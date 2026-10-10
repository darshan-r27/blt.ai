import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

// Home grouped by level (DECISIONS 039, 043). Fake text only; lessons come from `PreviewCatalog.lesson`,
// four items each, ids `<lesson>-i1` to `<lesson>-i4`.

private let now = Date(timeIntervalSince1970: 1_000_000)

private func level(_ number: Int, position: Int) -> Level {
    Level(number: number, title: "zz Title \(number)", position: position)
}

private func snapshot(correct ids: [String], wrong: [String] = []) -> ProgressSnapshot {
    func state(_ id: String, _ outcome: Outcome) -> ReviewState {
        ReviewState(
            itemID: ItemID(rawValue: id),
            repetitions: 1,
            intervalDays: 1,
            easeFactor: 2.5,
            due: now,
            lastOutcome: outcome,
            lastReviewed: now
        )
    }
    let states = ids.map { state($0, .correct) } + wrong.map { state($0, .wrong) }
    return ProgressSnapshot(reviews: Dictionary(uniqueKeysWithValues: states.map { ($0.itemID, $0) }), attempts: [])
}

/// All four items of the named lessons.
private func allItems(of lessons: [String]) -> [String] {
    lessons.flatMap { lesson in (1...4).map { "\(lesson)-i\($0)" } }
}

@MainActor
private func loadedModel(_ scenarios: [Scenario], progress: ProgressSnapshot = .empty) async -> HomeViewModel {
    let dependencies = AppDependencies(
        catalog: Catalog(scenarios: scenarios, issues: []),
        store: InMemoryProgressStore(initial: progress),
        scheduler: SM2Scheduler(),
        now: { now }
    )
    let model = HomeViewModel(dependencies: dependencies)
    await model.load()
    return model
}

@MainActor
struct HomeLevelsTests {
    // MARK: Ordering

    @Test func levelsAreInAscendingOrderAndLessonsSortByPositionThenID() async {
        let model = await loadedModel([
            PreviewCatalog.lesson("zz-c", title: "zz C", level: level(2, position: 1)),
            PreviewCatalog.lesson("zz-b", title: "zz B", level: level(1, position: 2)),
            PreviewCatalog.lesson("zz-z", title: "zz Z", level: level(1, position: 1)),
            PreviewCatalog.lesson("zz-a", title: "zz A", level: level(1, position: 2)),
            PreviewCatalog.lesson("zz-d", title: "zz D", level: level(3, position: 1))
        ])
        let sections = model.levelSections
        #expect(sections.map(\.number) == [1, 2, 3])
        // Position first (zz-z is position 1), then id for equal positions (zz-a before zz-b).
        #expect(sections[0].lessons.map(\.id.rawValue) == ["zz-z", "zz-a", "zz-b"])
        #expect(sections[0].title == "zz Title 1")
        #expect(sections[0].headerTitle == "Level 1: zz Title 1")
    }

    @Test func theLeveledPreviewCatalogIsOrderedWhateverItsFileOrder() async {
        let model = await loadedModel(PreviewCatalog.leveledCatalog.scenarios)
        #expect(model.levelSections.map(\.number) == [1, 2])
        #expect(model.levelSections[0].lessons.map(\.id.rawValue) == ["zz-l1-a", "zz-l1-b"])
        #expect(model.levelSections[1].lessons.map(\.id.rawValue) == ["zz-l2-a", "zz-l2-b"])
        #expect(model.otherLessons.map(\.id.rawValue) == ["zz-loose"])
    }

    @Test func theLeveledPreviewCatalogIsObviouslyFake() {
        for scenario in PreviewCatalog.leveledCatalog.scenarios {
            #expect(scenario.id.rawValue.hasPrefix("zz"))
            #expect(scenario.title.hasPrefix("zz"))
            #expect(scenario.level?.title.hasPrefix("zz") ?? true)
            for item in scenario.items {
                for text in [item.id.rawValue, item.sourcePrompt, item.canonical] + item.acceptedAnswers
                    + item.distractors { #expect(text.hasPrefix("zz")) }
            }
        }
    }

    // MARK: Completion

    @Test func levelCompletionAddsItemsAcrossItsLessons() async throws {
        let progress = snapshot(
            correct: allItems(of: ["zz-a"]) + ["zz-b-i1"],
            wrong: ["zz-b-i2"]
        )
        let model = await loadedModel(
            [
                PreviewCatalog.lesson("zz-a", title: "zz A", level: level(1, position: 1)),
                PreviewCatalog.lesson("zz-b", title: "zz B", level: level(1, position: 2)),
                PreviewCatalog.lesson("zz-c", title: "zz C", level: level(2, position: 1))
            ],
            progress: progress
        )
        let first = try #require(model.levelSections.first)
        #expect(first.totalCount == 8)
        // A wrong answer is not complete (DECISIONS 033); only latest-correct items count.
        #expect(first.completedCount == 5)
        #expect(first.completionPercent == 62)
        #expect(first.isComplete == false)
        let second = try #require(model.levelSections.last)
        #expect(second.completionPercent == 0)
        #expect(first.accessibilityLabel == "Level 1, zz Title 1")
        #expect(first.accessibilityValue(isExpanded: true) == "62 percent complete, expanded")
        #expect(first.accessibilityValue(isExpanded: false) == "62 percent complete, collapsed")
    }

    @Test func aLevelWithEveryItemCorrectIsOneHundredPercentAndComplete() async throws {
        let model = await loadedModel(
            [PreviewCatalog.lesson("zz-a", title: "zz A", level: level(1, position: 1))],
            progress: snapshot(correct: allItems(of: ["zz-a"]))
        )
        let section = try #require(model.levelSections.first)
        #expect(section.completionPercent == 100)
        #expect(section.isComplete)
    }

    @Test func aLevelWithNoItemsIsZeroPercentAndNeverComplete() async throws {
        let empty = Scenario(
            id: ScenarioID(rawValue: "zz-empty"),
            title: "zz Empty",
            subtitle: "zz sub",
            romanisationNote: nil,
            items: [],
            level: level(1, position: 1),
            language: .tamil
        )
        let model = await loadedModel([empty])
        let section = try #require(model.levelSections.first)
        #expect(section.completionPercent == 0)
        #expect(section.isComplete == false)
        #expect(model.continueLesson == nil)
    }

    // MARK: Continue

    @Test func continueIsTheFirstLessonWhenNothingIsDone() async {
        let model = await loadedModel(PreviewCatalog.leveledCatalog.scenarios)
        #expect(model.continueLesson?.id.rawValue == "zz-l1-a")
    }

    @Test func continueMovesWithinALevelByPosition() async {
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-a"]))
        )
        #expect(model.continueLesson?.id.rawValue == "zz-l1-b")
    }

    @Test func continueMovesToTheSecondLevelWhenTheFirstIsFinished() async {
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-a", "zz-l1-b"]))
        )
        #expect(model.continueLesson?.id.rawValue == "zz-l2-a")
    }

    @Test func continueIsOnlyTheEarliestUnfinishedLessonEvenIfLaterOnesAreDone() async {
        // A learner who skipped ahead: the suggestion still points at the earliest unfinished lesson.
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-b", "zz-l2-a"]))
        )
        #expect(model.continueLesson?.id.rawValue == "zz-l1-a")
    }

    @Test func continueFallsToLessonsWithNoLevelAfterTheLevels() async {
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-a", "zz-l1-b", "zz-l2-a", "zz-l2-b"]))
        )
        #expect(model.continueLesson?.id.rawValue == "zz-loose")
    }

    @Test func continueIsNilWhenEverythingIsComplete() async {
        let every = allItems(of: ["zz-l1-a", "zz-l1-b", "zz-l2-a", "zz-l2-b", "zz-loose"])
        let model = await loadedModel(PreviewCatalog.leveledCatalog.scenarios, progress: snapshot(correct: every))
        #expect(model.continueLesson == nil)
    }

    @Test func continueWorksWithNoLevelsAtAll() async {
        let model = await loadedModel(
            [
                PreviewCatalog.lesson("zz-x", title: "zz X", level: nil),
                PreviewCatalog.lesson("zz-y", title: "zz Y", level: nil)
            ],
            progress: snapshot(correct: allItems(of: ["zz-x"]))
        )
        #expect(model.continueLesson?.id.rawValue == "zz-y")
    }

    @Test func continueIsNilWhenThereAreNoLessons() async {
        let model = await loadedModel([])
        #expect(model.continueLesson == nil)
        #expect(model.levelSections.isEmpty)
        #expect(model.otherLessons.isEmpty)
    }

    // MARK: Collapse

    @Test func finishedLevelsStartCollapsedAndTheRestExpanded() async throws {
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-a", "zz-l1-b"]))
        )
        let finished = try #require(model.levelSections.first)
        let started = try #require(model.levelSections.last)
        #expect(model.isExpanded(finished) == false)
        #expect(model.isExpanded(started))
    }

    @Test func theLearnerCanOpenAFinishedLevelAndCloseAnUnfinishedOne() async throws {
        let model = await loadedModel(
            PreviewCatalog.leveledCatalog.scenarios,
            progress: snapshot(correct: allItems(of: ["zz-l1-a", "zz-l1-b"]))
        )
        let finished = try #require(model.levelSections.first)
        let started = try #require(model.levelSections.last)

        model.toggle(finished)
        #expect(model.isExpanded(finished))
        model.toggle(finished)
        #expect(model.isExpanded(finished) == false)

        model.toggle(started)
        #expect(model.isExpanded(started) == false)
        model.toggle(started)
        #expect(model.isExpanded(started))
    }

    @Test func aLearnersChoiceSurvivesAReload() async throws {
        let model = await loadedModel(PreviewCatalog.leveledCatalog.scenarios)
        let first = try #require(model.levelSections.first)
        model.toggle(first)
        await model.load()
        #expect(model.isExpanded(try #require(model.levelSections.first)) == false)
    }

    @Test func aNewViewModelGoesBackToTheDefaults() async throws {
        let scenarios = PreviewCatalog.leveledCatalog.scenarios
        let model = await loadedModel(scenarios)
        model.toggle(try #require(model.levelSections.first))
        let fresh = await loadedModel(scenarios)
        #expect(fresh.isExpanded(try #require(fresh.levelSections.first)))
    }

    // MARK: Other lessons

    @Test func lessonsWithoutALevelStayOutOfEveryLevelSection() async {
        let model = await loadedModel(PreviewCatalog.leveledCatalog.scenarios)
        let inLevels = model.levelSections.flatMap(\.lessons).map(\.id.rawValue)
        #expect(inLevels.contains("zz-loose") == false)
        #expect(model.otherLessons.map(\.id.rawValue) == ["zz-loose"])
        #expect(inLevels.count + model.otherLessons.count == model.scenarios.count)
    }

    @Test func aCatalogWithNoLevelsPutsEverythingUnderOtherLessonsInCatalogOrder() async {
        let model = await loadedModel(
            [
                PreviewCatalog.lesson("zz-q", title: "zz Q", level: nil),
                PreviewCatalog.lesson("zz-p", title: "zz P", level: nil)
            ]
        )
        #expect(model.levelSections.isEmpty)
        #expect(model.otherLessons.map(\.id.rawValue) == ["zz-q", "zz-p"])
        #expect(model.scenarios.count == 2)
    }

    @Test func theUITestFixtureHasNoLevelSoItAppearsUnderOtherLessons() async {
        let model = await loadedModel(PreviewCatalog.catalog.scenarios)
        #expect(model.levelSections.isEmpty)
        #expect(model.otherLessons.map(\.id.rawValue) == ["zz-scenario"])
        #expect(model.continueLesson?.id.rawValue == "zz-scenario")
    }

    // MARK: Language line

    @Test(arguments: CourseLanguage.allCases)
    func theLanguageLineNamesTheCourse(language: CourseLanguage) {
        #expect(HomeViewModel.languageLine(for: language) == "Learning \(language.displayName)")
    }

    @Test func noLanguageMeansNoLine() {
        #expect(HomeViewModel.languageLine(for: nil) == nil)
    }
}
