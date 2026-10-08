import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// A store for tests that can fail on load or erase, and counts how often it was asked to erase.
private actor HomeStubStore: ProgressStore {
    private var snapshot: ProgressSnapshot
    private var loadError: ProgressStoreError?
    private let eraseError: ProgressStoreError?
    private(set) var eraseCount = 0

    init(
        snapshot: ProgressSnapshot = .empty,
        loadError: ProgressStoreError? = nil,
        eraseError: ProgressStoreError? = nil
    ) {
        self.snapshot = snapshot
        self.loadError = loadError
        self.eraseError = eraseError
    }

    func load() async throws(ProgressStoreError) -> ProgressSnapshot {
        if let loadError { throw loadError }
        return snapshot
    }

    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {}

    func eraseAll() async throws(ProgressStoreError) {
        eraseCount += 1
        if let eraseError { throw eraseError }
        loadError = nil
        snapshot = .empty
    }
}

private let now = Date(timeIntervalSince1970: 1_000_000)
private let day: TimeInterval = 86_400

private func makeItem(_ id: String, scenario: String, status: ReviewStatus, hasVariant: Bool) -> Item {
    let distractorCount = hasVariant ? 2 : 3
    return Item(
        id: ItemID(rawValue: id),
        scenarioID: ScenarioID(rawValue: scenario),
        sourcePrompt: "zz prompt \(id)",
        register: hasVariant ? .casual : .neutral,
        addressee: .any,
        canonical: "zz canonical \(id)",
        acceptedAnswers: ["zz canonical \(id)", "zz alt a \(id)", "zz alt b \(id)"],
        registerVariant: hasVariant ? "zz variant \(id)" : nil,
        distractors: (1...distractorCount).map { "zz wrong \($0) \(id)" },
        tokens: [Token(tamil: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: status
    )
}

private func makeCatalog() -> Catalog {
    let first = Scenario(
        id: ScenarioID(rawValue: "zz-a"),
        title: "zz A",
        subtitle: "zz sub A",
        romanisationNote: nil,
        items: [
            makeItem("zz-a1", scenario: "zz-a", status: .reviewed, hasVariant: true),
            makeItem("zz-a2", scenario: "zz-a", status: .unreviewed, hasVariant: true),
            makeItem("zz-a3", scenario: "zz-a", status: .reviewed, hasVariant: false),
            makeItem("zz-a4", scenario: "zz-a", status: .unreviewed, hasVariant: false)
        ]
    )
    let second = Scenario(
        id: ScenarioID(rawValue: "zz-b"),
        title: "zz B",
        subtitle: "zz sub B",
        romanisationNote: nil,
        items: [
            makeItem("zz-b1", scenario: "zz-b", status: .reviewed, hasVariant: false),
            makeItem("zz-b2", scenario: "zz-b", status: .unreviewed, hasVariant: false)
        ]
    )
    return Catalog(scenarios: [first, second], issues: [])
}

private func review(_ id: String, repetitions: Int, due: Date, outcome: Outcome) -> ReviewState {
    ReviewState(
        itemID: ItemID(rawValue: id),
        repetitions: repetitions,
        intervalDays: 1,
        easeFactor: 2.5,
        due: due,
        lastOutcome: outcome,
        lastReviewed: now.addingTimeInterval(-day)
    )
}

private func attempt(_ id: String, _ outcome: Outcome) -> AttemptRecord {
    AttemptRecord(itemID: ItemID(rawValue: id), outcome: outcome, date: now.addingTimeInterval(-day))
}

/// a1 correct, a2 wrong, a3 correct, a4 never answered. b1 answered in the other register, b2 never answered.
/// One stale review and attempt for an item that is not in the catalog, which must be ignored.
private func seededSnapshot() -> ProgressSnapshot {
    let reviews = [
        review("zz-a1", repetitions: 2, due: now.addingTimeInterval(-1), outcome: .correct),
        review("zz-a2", repetitions: 0, due: now, outcome: .wrong),
        review("zz-a3", repetitions: 3, due: now.addingTimeInterval(day), outcome: .correct),
        review("zz-b1", repetitions: 1, due: now.addingTimeInterval(day), outcome: .wrongRegister),
        review("zz-gone", repetitions: 5, due: now.addingTimeInterval(-day), outcome: .correct)
    ]
    return ProgressSnapshot(
        reviews: Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) }),
        attempts: [
            attempt("zz-a1", .correct),
            attempt("zz-a1", .wrongRegister),
            attempt("zz-a2", .wrong),
            attempt("zz-a3", .correct),
            attempt("zz-gone", .correct)
        ]
    )
}

private func makeDependencies(store: any ProgressStore) -> AppDependencies {
    AppDependencies(catalog: makeCatalog(), store: store, scheduler: SM2Scheduler(), now: { now })
}

@MainActor
struct HomeViewModelTests {
    @Test func completionFollowsLatestOutcomeInSeededProgress() async throws {
        let store = InMemoryProgressStore(initial: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        let first = try #require(model.scenarios.first { $0.id.rawValue == "zz-a" })
        #expect(first.title == "zz A")
        #expect(first.totalCount == 4)
        // a1 and a3 are correct; a2 is wrong; a4 was never answered. The stale item is ignored.
        #expect(first.completedCount == 2)
        #expect(first.completionFraction == 0.5)
        #expect(first.completionPercent == 50)

        let second = try #require(model.scenarios.first { $0.id.rawValue == "zz-b" })
        #expect(second.totalCount == 2)
        // b1 was answered in the other register and b2 never: neither is complete.
        #expect(second.completedCount == 0)
        #expect(second.completionPercent == 0)
        #expect(model.loadError == nil)
    }

    @Test func emptyProgressIsZeroPercent() async throws {
        let model = HomeViewModel(dependencies: makeDependencies(store: InMemoryProgressStore()))
        await model.load()
        #expect(model.scenarios.count == 2)
        for scenario in model.scenarios {
            #expect(scenario.completedCount == 0)
            #expect(scenario.completionFraction == 0)
            #expect(scenario.completionPercent == 0)
        }
    }

    @Test func everyItemLatestCorrectIsOneHundredPercent() async throws {
        let reviews = ["zz-b1", "zz-b2"].map { review($0, repetitions: 1, due: now, outcome: .correct) }
        let snapshot = ProgressSnapshot(
            reviews: Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) }),
            attempts: []
        )
        let model = HomeViewModel(dependencies: makeDependencies(store: InMemoryProgressStore(initial: snapshot)))
        await model.load()
        let second = try #require(model.scenarios.first { $0.id.rawValue == "zz-b" })
        #expect(second.completedCount == 2)
        #expect(second.completionFraction == 1)
        #expect(second.completionPercent == 100)
        let first = try #require(model.scenarios.first { $0.id.rawValue == "zz-a" })
        #expect(first.completionPercent == 0)
    }

    @Test(arguments: Outcome.allCases)
    func onlyACorrectLatestOutcomeCompletesAnItem(outcome: Outcome) throws {
        let only = review("zz-b1", repetitions: 1, due: now, outcome: outcome)
        let snapshot = ProgressSnapshot(reviews: [only.itemID: only], attempts: [])
        let scenario = try #require(makeCatalog().scenarios.first { $0.id.rawValue == "zz-b" })
        let summary = ScenarioSummary(scenario: scenario, snapshot: snapshot)
        #expect(summary.completedCount == (outcome == .correct ? 1 : 0))
    }

    @Test func aWrongAnswerAfterACorrectOneMakesTheItemIncompleteAgain() throws {
        let scenario = try #require(makeCatalog().scenarios.first { $0.id.rawValue == "zz-b" })
        let id = ItemID(rawValue: "zz-b1")

        let correct = review("zz-b1", repetitions: 1, due: now, outcome: .correct)
        let before = ScenarioSummary(
            scenario: scenario,
            snapshot: ProgressSnapshot(reviews: [id: correct], attempts: [attempt("zz-b1", .correct)])
        )
        #expect(before.completionPercent == 50)

        // The attempt log still holds the earlier correct answer; only the latest outcome counts.
        let wrong = review("zz-b1", repetitions: 0, due: now, outcome: .wrong)
        let after = ScenarioSummary(
            scenario: scenario,
            snapshot: ProgressSnapshot(
                reviews: [id: wrong],
                attempts: [attempt("zz-b1", .correct), attempt("zz-b1", .wrong)]
            )
        )
        #expect(after.completedCount == 0)
        #expect(after.completionPercent == 0)
    }

    @Test func percentRoundsDownSoOnlyAFullScenarioShowsOneHundred() {
        func summary(completed: Int, of total: Int) -> ScenarioSummary {
            let items = (1...total).map {
                makeItem("zz-p\($0)", scenario: "zz-p", status: .unreviewed, hasVariant: false)
            }
            let scenario = Scenario(
                id: ScenarioID(rawValue: "zz-p"),
                title: "zz P",
                subtitle: "zz sub P",
                romanisationNote: nil,
                items: items
            )
            let reviews = items.prefix(completed).map {
                review($0.id.rawValue, repetitions: 1, due: now, outcome: .correct)
            }
            let snapshot = ProgressSnapshot(
                reviews: Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) }),
                attempts: []
            )
            return ScenarioSummary(scenario: scenario, snapshot: snapshot)
        }
        #expect(summary(completed: 7, of: 20).completionPercent == 35)
        #expect(summary(completed: 1, of: 3).completionPercent == 33)
        #expect(summary(completed: 2, of: 3).completionPercent == 66)
        #expect(summary(completed: 199, of: 200).completionPercent == 99)
        #expect(summary(completed: 20, of: 20).completionPercent == 100)
    }

    @Test func aScenarioWithNoItemsIsZeroPercentNotADivisionByZero() {
        let scenario = Scenario(
            id: ScenarioID(rawValue: "zz-none"),
            title: "zz None",
            subtitle: "zz sub",
            romanisationNote: nil,
            items: []
        )
        let summary = ScenarioSummary(scenario: scenario, snapshot: .empty)
        #expect(summary.totalCount == 0)
        #expect(summary.completionFraction == 0)
        #expect(summary.completionPercent == 0)
    }

    @Test func confirmingResetErasesAndReloadsEmpty() async throws {
        let store = HomeStubStore(snapshot: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()
        #expect(try #require(model.scenarios.first).completedCount == 2)

        model.requestReset()
        #expect(model.isConfirmingReset)
        #expect(await store.eraseCount == 0)

        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.isConfirmingReset == false)
        #expect(model.resetError == nil)
        let first = try #require(model.scenarios.first)
        #expect(first.completedCount == 0)
        #expect(first.completionPercent == 0)
    }

    @Test func cancellingResetErasesNothing() async {
        let store = HomeStubStore(snapshot: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        model.requestReset()
        model.cancelReset()
        #expect(model.isConfirmingReset == false)
        #expect(await store.eraseCount == 0)
        #expect(model.scenarios.first?.completedCount == 2)
    }

    @Test func corruptStoreShowsErrorAndNeverAutoResets() async {
        let store = HomeStubStore(snapshot: seededSnapshot(), loadError: .corrupt)
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()
        await model.load()

        #expect(model.loadError == .corrupt)
        #expect(model.canOfferReset)
        #expect(model.scenarios.isEmpty)
        #expect(await store.eraseCount == 0)

        model.requestReset()
        #expect(await store.eraseCount == 0)
    }

    @Test func resetOfCorruptStoreRecoversToEmpty() async {
        let store = HomeStubStore(loadError: .corrupt)
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()
        #expect(model.loadError == .corrupt)

        model.requestReset()
        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.loadError == nil)
        #expect(model.scenarios.count == 2)
    }

    @Test func unsupportedVersionOffersResetButUnreadableDoesNot() async {
        let newerStore = HomeStubStore(loadError: .unsupportedSchemaVersion(9))
        let newer = HomeViewModel(dependencies: makeDependencies(store: newerStore))
        await newer.load()
        #expect(newer.loadError == .unsupportedSchemaVersion(9))
        #expect(newer.canOfferReset)

        let unreadableStore = HomeStubStore(loadError: .unreadable)
        let unreadable = HomeViewModel(dependencies: makeDependencies(store: unreadableStore))
        await unreadable.load()
        #expect(unreadable.loadError == .unreadable)
        #expect(unreadable.canOfferReset == false)
    }

    @Test func resetFailureIsSurfacedAndErrorStays() async {
        let store = HomeStubStore(loadError: .corrupt, eraseError: .eraseFailed)
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        model.requestReset()
        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.resetError == .eraseFailed)
        #expect(model.loadError == .corrupt)
        #expect(model.scenarios.isEmpty)
    }

    @Test func greetingUsesTheNameAsGiven() {
        #expect(HomeViewModel.greeting(forName: "zz Sample") == "Hi zz Sample")
        #expect(HomeViewModel.greeting(forName: "zz Sample Name") == "Hi zz Sample Name")
    }
}
