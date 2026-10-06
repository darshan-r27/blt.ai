import BLTCatalog
import BLTCore
import BLTFeatures
import BLTProgress
import Foundation
import Testing

/// Counts erase calls and can be told to fail them.
private actor SettingsStubStore: ProgressStore {
    private let eraseError: ProgressStoreError?
    private(set) var eraseCount = 0

    init(eraseError: ProgressStoreError? = nil) {
        self.eraseError = eraseError
    }

    func load() async throws(ProgressStoreError) -> ProgressSnapshot { .empty }

    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) {}

    func eraseAll() async throws(ProgressStoreError) {
        eraseCount += 1
        if let eraseError { throw eraseError }
    }
}

/// Records whether the reset callback fired.
@MainActor
private final class ResetCounter {
    var fired = false
}

private func makeDependencies(store: any ProgressStore) -> AppDependencies {
    let items = [
        makeItem("zz-s1", status: .reviewed),
        makeItem("zz-s2", status: .unreviewed),
        makeItem("zz-s3", status: .unreviewed)
    ]
    let scenario = Scenario(
        id: ScenarioID(rawValue: "zz-s"),
        title: "zz S",
        subtitle: "zz sub",
        romanisationNote: nil,
        items: items
    )
    return AppDependencies(
        catalog: Catalog(scenarios: [scenario], issues: []),
        store: store,
        scheduler: SM2Scheduler(),
        now: { Date(timeIntervalSince1970: 1_000_000) }
    )
}

private func makeItem(_ id: String, status: ReviewStatus) -> Item {
    Item(
        id: ItemID(rawValue: id),
        scenarioID: ScenarioID(rawValue: "zz-s"),
        sourcePrompt: "zz prompt",
        register: .neutral,
        addressee: .any,
        canonical: "zz canonical",
        acceptedAnswers: ["zz canonical", "zz alt a", "zz alt b"],
        registerVariant: nil,
        distractors: ["zz wrong a", "zz wrong b", "zz wrong c"],
        tokens: [Token(tamil: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: status
    )
}

@MainActor
struct SettingsViewModelTests {
    @Test func reviewedCountIsComputedFromTheCatalog() {
        let model = SettingsViewModel(dependencies: makeDependencies(store: SettingsStubStore()))
        #expect(model.reviewedCount == 1)
        #expect(model.totalCount == 3)
    }

    @Test func requestingResetDoesNotErase() async {
        let store = SettingsStubStore()
        let model = SettingsViewModel(dependencies: makeDependencies(store: store))
        model.requestReset()
        #expect(model.isConfirmingReset)
        #expect(await store.eraseCount == 0)
        #expect(model.resetOutcome == nil)
    }

    @Test func cancellingResetDoesNotErase() async {
        let store = SettingsStubStore()
        let model = SettingsViewModel(dependencies: makeDependencies(store: store))
        model.requestReset()
        model.cancelReset()
        #expect(model.isConfirmingReset == false)
        #expect(await store.eraseCount == 0)
        #expect(model.resetOutcome == nil)
    }

    @Test func confirmingResetErasesAndReportsSuccess() async {
        let store = SettingsStubStore()
        let counter = ResetCounter()
        let model = SettingsViewModel(dependencies: makeDependencies(store: store)) { counter.fired = true }
        model.requestReset()
        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.resetOutcome == .succeeded)
        #expect(model.isConfirmingReset == false)
        #expect(counter.fired)
    }

    @Test func confirmingResetClearsSeededProgress() async throws {
        let item = ItemID(rawValue: "zz-s1")
        let review = ReviewState(
            itemID: item,
            repetitions: 2,
            intervalDays: 6,
            easeFactor: 2.5,
            due: Date(timeIntervalSince1970: 2_000_000),
            lastOutcome: .correct,
            lastReviewed: Date(timeIntervalSince1970: 1_000_000)
        )
        let attempt = AttemptRecord(itemID: item, outcome: .correct, date: Date(timeIntervalSince1970: 1_000_000))
        let store = InMemoryProgressStore(initial: ProgressSnapshot(reviews: [item: review], attempts: [attempt]))
        let model = SettingsViewModel(dependencies: makeDependencies(store: store))
        model.requestReset()
        await model.confirmReset()
        #expect(try await store.load() == .empty)
    }

    @Test func resetFailureIsSurfacedAndDoesNotNotifyOwner() async {
        let store = SettingsStubStore(eraseError: .eraseFailed)
        let counter = ResetCounter()
        let model = SettingsViewModel(dependencies: makeDependencies(store: store)) { counter.fired = true }
        model.requestReset()
        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.resetOutcome == .failed(.eraseFailed))
        #expect(counter.fired == false)
    }
}
