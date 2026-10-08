import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

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

/// Records the names the owner was told about.
@MainActor
private final class NameCounter {
    private(set) var profiles: [UserProfile] = []
    func record(_ profile: UserProfile) { profiles.append(profile) }
}

@MainActor
private func makeModel(
    store: any ProgressStore,
    allReviewed: Bool = false,
    profileStore: any ProfileStore = InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
    onDidReset: @escaping @MainActor () -> Void = {},
    onDidChangeName: @escaping @MainActor (UserProfile) -> Void = { _ in }
) -> SettingsViewModel {
    SettingsViewModel(
        dependencies: makeDependencies(store: store, allReviewed: allReviewed),
        profileStore: profileStore,
        profileName: "zz Sample",
        onDidReset: onDidReset,
        onDidChangeName: onDidChangeName
    )
}

private func makeDependencies(store: any ProgressStore, allReviewed: Bool = false) -> AppDependencies {
    let rest: ReviewStatus = allReviewed ? .reviewed : .unreviewed
    let items = [
        makeItem("zz-s1", status: .reviewed),
        makeItem("zz-s2", status: rest),
        makeItem("zz-s3", status: rest)
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
        let model = makeModel(store: SettingsStubStore())
        #expect(model.reviewedCount == 1)
        #expect(model.totalCount == 3)
    }

    @Test func contentStatementIsTheDraftWordingUntilEverythingIsReviewed() {
        let model = makeModel(store: SettingsStubStore())
        #expect(!model.allContentReviewed)
        #expect(model.contentStatement.contains("drafted by an AI"))
        #expect(!model.contentStatement.contains("Every lesson"))
    }

    @Test func contentStatementClaimsNativeReviewOnlyWhenEveryItemIsReviewed() {
        let model = makeModel(store: SettingsStubStore(), allReviewed: true)
        #expect(model.allContentReviewed)
        #expect(model.contentStatement.hasPrefix("Every lesson was checked by a native Tamil speaker"))
    }

    @Test func requestingResetDoesNotErase() async {
        let store = SettingsStubStore()
        let model = makeModel(store: store)
        model.requestReset()
        #expect(model.isConfirmingReset)
        #expect(await store.eraseCount == 0)
        #expect(model.resetOutcome == nil)
    }

    @Test func cancellingResetDoesNotErase() async {
        let store = SettingsStubStore()
        let model = makeModel(store: store)
        model.requestReset()
        model.cancelReset()
        #expect(model.isConfirmingReset == false)
        #expect(await store.eraseCount == 0)
        #expect(model.resetOutcome == nil)
    }

    @Test func confirmingResetErasesAndReportsSuccess() async {
        let store = SettingsStubStore()
        let counter = ResetCounter()
        let model = makeModel(store: store, onDidReset: { counter.fired = true })
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
        let model = makeModel(store: store)
        model.requestReset()
        await model.confirmReset()
        #expect(try await store.load() == .empty)
    }

    @Test func resetFailureIsSurfacedAndDoesNotNotifyOwner() async {
        let store = SettingsStubStore(eraseError: .eraseFailed)
        let counter = ResetCounter()
        let model = makeModel(store: store, onDidReset: { counter.fired = true })
        model.requestReset()
        await model.confirmReset()
        #expect(await store.eraseCount == 1)
        #expect(model.resetOutcome == .failed(.eraseFailed))
        #expect(counter.fired == false)
    }

    @Test func showsTheSavedNameAndOpensNoEditorUntilAsked() {
        let model = makeModel(store: SettingsStubStore())
        #expect(model.profileName == "zz Sample")
        #expect(model.nameEditor == nil)
    }

    @Test func cancellingChangeNameChangesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let names = NameCounter()
        let model = makeModel(
            store: SettingsStubStore(),
            profileStore: profileStore,
            onDidChangeName: { names.record($0) }
        )
        model.beginChangeName()
        #expect(model.nameEditor?.name == "zz Sample")
        model.nameEditor?.updateName("zz Other")
        model.cancelChangeName()
        #expect(model.nameEditor == nil)
        #expect(model.profileName == "zz Sample")
        #expect(names.profiles.isEmpty)
        #expect(await profileStore.saveCount == 0)
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Sample"))
    }

    @Test func savingANewNameUpdatesImmediatelyAndNotifiesTheOwner() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let names = NameCounter()
        let model = makeModel(
            store: SettingsStubStore(),
            profileStore: profileStore,
            onDidChangeName: { names.record($0) }
        )
        model.beginChangeName()
        model.nameEditor?.updateName("  zz   Other ")
        await model.nameEditor?.submit()
        #expect(model.profileName == "zz Other")
        #expect(model.nameEditor == nil)
        #expect(names.profiles == [UserProfile(name: "zz Other")])
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Other"))
    }

    @Test func invalidNewNameKeepsTheSheetOpenAndSavesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let model = makeModel(store: SettingsStubStore(), profileStore: profileStore)
        model.beginChangeName()
        model.nameEditor?.updateName("   ")
        await model.nameEditor?.submit()
        #expect(model.nameEditor?.problem == .invalid(.empty))
        #expect(model.profileName == "zz Sample")
        #expect(await profileStore.saveCount == 0)
    }

    @Test func failedNameSaveKeepsTheSheetOpenAndTheOldName() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"), saveError: .writeFailed)
        let names = NameCounter()
        let model = makeModel(
            store: SettingsStubStore(),
            profileStore: profileStore,
            onDidChangeName: { names.record($0) }
        )
        model.beginChangeName()
        model.nameEditor?.updateName("zz Other")
        await model.nameEditor?.submit()
        #expect(model.nameEditor?.problem == .saveFailed(.writeFailed))
        #expect(model.profileName == "zz Sample")
        #expect(names.profiles.isEmpty)
    }

    @Test func resettingProgressDoesNotTouchTheName() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let model = makeModel(store: SettingsStubStore(), profileStore: profileStore)
        model.requestReset()
        await model.confirmReset()
        #expect(model.resetOutcome == .succeeded)
        #expect(model.profileName == "zz Sample")
        #expect(await profileStore.eraseCount == 0)
        #expect(await profileStore.saveCount == 0)
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Sample"))
    }
}
