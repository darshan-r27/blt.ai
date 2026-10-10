import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// A profile store that records every call and can be told to fail. Shared by the onboarding and
/// settings tests; fake names only.
actor OnboardingStubProfileStore: ProfileStore {
    private var profile: UserProfile?
    private let loadError: ProfileStoreError?
    private let saveError: ProfileStoreError?
    private let eraseError: ProfileStoreError?
    /// How many saves fail before they start to work; `nil` means "all of them, if `saveError` is set".
    private var failingSavesLeft: Int?
    private(set) var loadCount = 0
    private(set) var saveCount = 0
    private(set) var eraseCount = 0

    init(
        profile: UserProfile? = nil,
        loadError: ProfileStoreError? = nil,
        saveError: ProfileStoreError? = nil,
        eraseError: ProfileStoreError? = nil,
        failingSaves: Int? = nil
    ) {
        self.profile = profile
        self.loadError = loadError
        self.saveError = saveError
        self.eraseError = eraseError
        failingSavesLeft = failingSaves
    }

    func load() async throws(ProfileStoreError) -> UserProfile? {
        loadCount += 1
        if let loadError { throw loadError }
        return profile
    }

    func save(_ profile: UserProfile) async throws(ProfileStoreError) {
        saveCount += 1
        if let left = failingSavesLeft {
            if left > 0 {
                failingSavesLeft = left - 1
                throw .writeFailed
            }
        } else if let saveError {
            throw saveError
        }
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

    @Test func savedProfileWithALanguageGoesStraightToHomeWithTheName() async {
        let saved = UserProfile(name: "zz Sample", learningLanguage: .telugu)
        let store = OnboardingStubProfileStore(profile: saved)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .ready(saved))
        #expect(await store.saveCount == 0)
    }

    @Test func savedProfileWithoutALanguageAsksForOneAndKeepsTheName() async {
        let store = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .needsLanguage(UserProfile(name: "zz Sample")))
        #expect(await store.saveCount == 0)
    }

    @Test func savingTheNameDuringOnboardingMovesToTheLanguageStep() async {
        let store = OnboardingStubProfileStore()
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        let entry = gate.makeNameEntryViewModel()
        entry.updateName("zz Sample")
        await entry.submit()
        #expect(gate.state == .needsLanguage(UserProfile(name: "zz Sample")))
        #expect(await store.savedProfile == UserProfile(name: "zz Sample"))
    }

    @Test func firstLaunchPassesThroughIntroNameAndLanguageInOrder() async {
        let store = OnboardingStubProfileStore()
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .needsOnboarding)
        #expect(gate.onboardingStep == .intro)

        gate.showNameEntry()
        #expect(gate.state == .needsOnboarding)
        #expect(gate.onboardingStep == .nameEntry)

        let entry = gate.makeNameEntryViewModel()
        entry.updateName("zz Sample")
        await entry.submit()
        #expect(gate.state == .needsLanguage(UserProfile(name: "zz Sample")))

        let choice = gate.makeLanguageChoiceViewModel(profile: UserProfile(name: "zz Sample"))
        choice.select(.telugu)
        await choice.submit()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample", learningLanguage: .telugu)))
        #expect(await store.savedProfile == UserProfile(name: "zz Sample", learningLanguage: .telugu))
    }

    @Test func legacyProfileOnlyAsksForTheLanguage() async {
        let store = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        guard case .needsLanguage(let profile) = gate.state else {
            Issue.record("expected the language step, got \(gate.state)")
            return
        }
        let choice = gate.makeLanguageChoiceViewModel(profile: profile)
        choice.select(.tamil)
        await choice.submit()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample", learningLanguage: .tamil)))
        #expect(await store.savedProfile?.name == "zz Sample")
    }

    @Test func aFailedLanguageSaveStaysOnTheLanguageStepAndRetrySucceeds() async {
        let store = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"), failingSaves: 1)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        let choice = gate.makeLanguageChoiceViewModel(profile: UserProfile(name: "zz Sample"))
        choice.select(.telugu)
        await choice.submit()
        #expect(gate.state == .needsLanguage(UserProfile(name: "zz Sample")))
        #expect(choice.problemMessage != nil)

        await choice.submit()
        #expect(gate.state == .ready(UserProfile(name: "zz Sample", learningLanguage: .telugu)))
        #expect(choice.problemMessage == nil)
    }

    @Test func changingTheNameAfterwardsKeepsTheLanguage() async {
        let saved = UserProfile(name: "zz Sample", learningLanguage: .tamil)
        let store = OnboardingStubProfileStore(profile: saved)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        let entry = gate.makeNameEntryViewModel()
        entry.updateName("zz Other")
        await entry.submit()
        #expect(gate.state == .ready(UserProfile(name: "zz Other", learningLanguage: .tamil)))
        #expect(await store.savedProfile == UserProfile(name: "zz Other", learningLanguage: .tamil))
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
        let saved = UserProfile(name: "zz Sample", learningLanguage: .tamil)
        let store = FlakyProfileStore(profile: saved)
        let gate = ProfileGateViewModel(store: store)
        await gate.load()
        #expect(gate.state == .loadFailed(.unreadable))

        await gate.retry()
        #expect(gate.state == .ready(saved))
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
