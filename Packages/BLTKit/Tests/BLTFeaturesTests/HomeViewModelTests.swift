import BLTCatalog
import BLTCore
import BLTFeatures
import BLTProgress
import Foundation
import Testing

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

/// a1 due + learned; a2 due exactly now, not learned; a3 not due, learned; a4 new.
/// b1 not due, not learned; b2 new. One stale review and attempt for an item that is not in the catalog.
private func seededSnapshot() -> ProgressSnapshot {
    let reviews = [
        review("zz-a1", repetitions: 2, due: now.addingTimeInterval(-1), outcome: .correct),
        review("zz-a2", repetitions: 0, due: now, outcome: .wrong),
        review("zz-a3", repetitions: 3, due: now.addingTimeInterval(day), outcome: .correct),
        review("zz-b1", repetitions: 1, due: now.addingTimeInterval(day), outcome: .correct),
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
    @Test func perScenarioCountsMatchSeededProgress() async throws {
        let store = InMemoryProgressStore(initial: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        let first = try #require(model.scenarios.first { $0.id.rawValue == "zz-a" })
        #expect(first.title == "zz A")
        #expect(first.dueCount == 2)
        #expect(first.newCount == 1)
        #expect(first.learnedCount == 2)
        #expect(first.totalCount == 4)
        #expect(first.reviewedCount == 2)

        let second = try #require(model.scenarios.first { $0.id.rawValue == "zz-b" })
        #expect(second.dueCount == 0)
        #expect(second.newCount == 1)
        #expect(second.learnedCount == 0)
        #expect(second.totalCount == 2)
        #expect(second.reviewedCount == 1)
        #expect(model.loadError == nil)
    }

    @Test func emptyStoreMakesEverythingNew() async throws {
        let model = HomeViewModel(dependencies: makeDependencies(store: InMemoryProgressStore()))
        await model.load()
        let first = try #require(model.scenarios.first)
        #expect(first.dueCount == 0)
        #expect(first.newCount == first.totalCount)
        #expect(first.learnedCount == 0)
        #expect(model.summary?.registerAccuracy == nil)
    }

    @Test func summaryEqualsProgressSummary() async throws {
        let catalog = makeCatalog()
        let snapshot = seededSnapshot()
        let store = InMemoryProgressStore(initial: snapshot)
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        let variants = Set(catalog.scenarios.flatMap(\.items).filter { $0.registerVariant != nil }.map(\.id))
        let expected = ProgressSummary(
            snapshot: snapshot,
            knownItems: catalog.allItemIDs,
            variantItems: variants,
            now: now
        )
        #expect(model.summary == expected)
        // Hard-coded cross-check: a1 correct + wrongRegister on variant items; stale item ignored.
        #expect(model.summary?.registerAccuracy == 0.5)
        #expect(model.summary?.learnedCount == 2)
        #expect(model.summary?.dueCount == 2)
        #expect(model.summary?.attemptCount == 4)
    }

    @Test func confirmingResetErasesAndReloadsEmpty() async throws {
        let store = HomeStubStore(snapshot: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()
        #expect(try #require(model.scenarios.first).dueCount == 2)

        model.requestReset()
        #expect(model.isConfirmingReset)
        #expect(await store.eraseCount == 0)

        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.isConfirmingReset == false)
        #expect(model.resetError == nil)
        let first = try #require(model.scenarios.first)
        #expect(first.dueCount == 0)
        #expect(first.newCount == first.totalCount)
    }

    @Test func cancellingResetErasesNothing() async {
        let store = HomeStubStore(snapshot: seededSnapshot())
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()

        model.requestReset()
        model.cancelReset()
        #expect(model.isConfirmingReset == false)
        #expect(await store.eraseCount == 0)
        #expect(model.scenarios.first?.dueCount == 2)
    }

    @Test func corruptStoreShowsErrorAndNeverAutoResets() async {
        let store = HomeStubStore(snapshot: seededSnapshot(), loadError: .corrupt)
        let model = HomeViewModel(dependencies: makeDependencies(store: store))
        await model.load()
        await model.load()

        #expect(model.loadError == .corrupt)
        #expect(model.canOfferReset)
        #expect(model.scenarios.isEmpty)
        #expect(model.summary == nil)
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
