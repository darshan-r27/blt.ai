import BLTCore
import BLTFeatures
import BLTProgress
import Foundation
import Testing

/// A profile store that records every call and can be told to fail. Shared by the onboarding and
/// settings tests; fake names only.
actor OnboardingStubProfileStore: ProfileStore {
    private var profile: UserProfile?
    private let loadError: ProfileStoreError?
    private let saveError: ProfileStoreError?
    private let eraseError: ProfileStoreError?
    private(set) var loadCount = 0
    private(set) var saveCount = 0
    private(set) var eraseCount = 0

    init(
        profile: UserProfile? = nil,
        loadError: ProfileStoreError? = nil,
        saveError: ProfileStoreError? = nil,
        eraseError: ProfileStoreError? = nil
    ) {
        self.profile = profile
        self.loadError = loadError
        self.saveError = saveError
        self.eraseError = eraseError
    }

    func load() async throws(ProfileStoreError) -> UserProfile? {
        loadCount += 1
        if let loadError { throw loadError }
        return profile
    }

    func save(_ profile: UserProfile) async throws(ProfileStoreError) {
        saveCount += 1
        if let saveError { throw saveError }
        self.profile = profile
    }

    func erase() async throws(ProfileStoreError) {
        eraseCount += 1
        if let eraseError { throw eraseError }
        profile = nil
    }

    var savedProfile: UserProfile? { profile }
}

@MainActor
struct OnboardingGateTests {
    @Test func startsLoadingBeforeAnythingIsRead() {
        let gate = ProfileGateViewModel(store: OnboardingStubProfileStore())
        #expect(gate.state == .loading)
    }

    @Test func noProfileMeansOnboardingStartingAtTheIntro() async {
        let gate = ProfileGateViewModel(store: OnboardingStubProfileStore())
        await gate.load()
        #expect(gate.state == .needsOnboarding)
        #expect(gate.onboardingStep == .intro)
    }

    @Test func introLeadsToNameEntry() async {
        let gate = ProfileGateViewModel(store: OnboardingStubProfileStore())
        await gate.load()
        gate.showNameEntry()
        #expect(gate.onboardingStep == .nameEntry)
    }

    @Test func savedProfileGoesStraightToHomeWithTheName() async {
        let store = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample")))
        #expect(await store.saveCount == 0)
    }

    @Test func savingTheNameDuringOnboardingMovesToHome() async {
        let store = OnboardingStubProfileStore()
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        let entry = gate.makeNameEntryViewModel()
        entry.updateName("zz Sample")
        await entry.submit()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample")))
        #expect(await store.savedProfile == UserProfile(name: "zz Sample"))
    }

    @Test func failedSaveDuringOnboardingStaysOnNameEntry() async {
        let store = OnboardingStubProfileStore(saveError: .writeFailed)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        gate.showNameEntry()
        let entry = gate.makeNameEntryViewModel()
        entry.updateName("zz Sample")
        await entry.submit()
        #expect(gate.state == .needsOnboarding)
        #expect(gate.onboardingStep == .nameEntry)
        #expect(entry.problem == .saveFailed(.writeFailed))
    }

    @Test func corruptProfileIsNeverOverwrittenAndOffersStartOver() async {
        let store = OnboardingStubProfileStore(loadError: .corrupt)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .loadFailed(.corrupt))
        #expect(gate.canOfferStartOver)
        #expect(await store.saveCount == 0)
        #expect(await store.eraseCount == 0)
    }

    @Test func unsupportedVersionOffersStartOverToo() async {
        let gate = ProfileGateViewModel(store: OnboardingStubProfileStore(loadError: .unsupportedSchemaVersion(9)))
        await gate.load()
        #expect(gate.state == .loadFailed(.unsupportedSchemaVersion(9)))
        #expect(gate.canOfferStartOver)
    }

    @Test func requestingStartOverErasesNothing() async {
        let store = OnboardingStubProfileStore(loadError: .corrupt)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        gate.requestStartOver()
        #expect(gate.isConfirmingStartOver)
        #expect(await store.eraseCount == 0)
        #expect(gate.state == .loadFailed(.corrupt))
    }

    @Test func cancellingStartOverErasesNothing() async {
        let store = OnboardingStubProfileStore(loadError: .corrupt)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        gate.requestStartOver()
        gate.cancelStartOver()
        #expect(gate.isConfirmingStartOver == false)
        #expect(await store.eraseCount == 0)
        #expect(gate.state == .loadFailed(.corrupt))
    }

    @Test func confirmingStartOverErasesOnceThenShowsOnboardingAndLeavesProgressAlone() async throws {
        let progress = InMemoryProgressStore(initial: ProgressSnapshot(reviews: [:], attempts: [attemptFixture()]))
        let store = OnboardingStubProfileStore(loadError: .corrupt)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        gate.requestStartOver()
        await gate.confirmStartOver()
        #expect(await store.eraseCount == 1)
        #expect(gate.state == .needsOnboarding)
        #expect(gate.onboardingStep == .intro)
        #expect(await store.saveCount == 0)
        #expect(try await progress.load().attempts.count == 1)
    }

    @Test func startOverFailureIsSurfacedAndTheProblemScreenStays() async {
        let store = OnboardingStubProfileStore(loadError: .corrupt, eraseError: .eraseFailed)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        gate.requestStartOver()
        await gate.confirmStartOver()
        #expect(await store.eraseCount == 1)
        #expect(gate.startOverError == .eraseFailed)
        #expect(gate.state == .loadFailed(.corrupt))
    }

    @Test func startOverIsNotOfferedForAnUnreadableProfileAndNeverErases() async {
        let store = OnboardingStubProfileStore(loadError: .unreadable)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .loadFailed(.unreadable))
        #expect(gate.canOfferStartOver == false)

        gate.requestStartOver()
        await gate.confirmStartOver()
        #expect(await store.eraseCount == 0)
        #expect(gate.state == .loadFailed(.unreadable))
    }

    @Test func retryReadsAgainAndRecoversWhenTheProblemWasTransient() async {
        let store = FlakyProfileStore(profile: UserProfile(name: "zz Sample"))
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .loadFailed(.unreadable))

        await gate.retry()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample")))
    }
}

private func attemptFixture() -> AttemptRecord {
    AttemptRecord(
        itemID: ItemID(rawValue: "zz-gate-item"),
        outcome: .correct,
        date: Date(timeIntervalSince1970: 1_000_000)
    )
}

/// Fails the first load with `.unreadable`, then behaves normally.
private actor FlakyProfileStore: ProfileStore {
    private let profile: UserProfile
    private var hasFailed = false

    init(profile: UserProfile) {
        self.profile = profile
    }

    func load() async throws(ProfileStoreError) -> UserProfile? {
        if !hasFailed {
            hasFailed = true
            throw .unreadable
        }
        return profile
    }

    func save(_ profile: UserProfile) async throws(ProfileStoreError) {}

    func erase() async throws(ProfileStoreError) {}
}
