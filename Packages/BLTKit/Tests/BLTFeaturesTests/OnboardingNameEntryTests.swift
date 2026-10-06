import BLTFeatures
import BLTProgress
import Foundation
import Testing

/// Collects what `onSaved` was called with.
@MainActor
private final class SavedRecorder {
    private(set) var profiles: [UserProfile] = []
    func record(_ profile: UserProfile) { profiles.append(profile) }
}

@MainActor
struct OnboardingNameEntryTests {
    private func makeModel(
        store: OnboardingStubProfileStore,
        recorder: SavedRecorder,
        initialName: String = ""
    ) -> NameEntryViewModel {
        NameEntryViewModel(store: store, initialName: initialName) { recorder.record($0) }
    }

    @Test func validNameIsSavedAndReported() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.updateName("zz Sample")
        await model.submit()
        #expect(await store.savedProfile == UserProfile(name: "zz Sample"))
        #expect(recorder.profiles == [UserProfile(name: "zz Sample")])
        #expect(model.problem == nil)
        #expect(model.problemMessage == nil)
    }

    @Test func paddedAndSpacedNameIsTrimmedAndCollapsedBeforeSaving() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.updateName("   zz   Sample \u{00A0} Name  ")
        await model.submit()
        #expect(await store.savedProfile == UserProfile(name: "zz Sample Name"))
        #expect(recorder.profiles == [UserProfile(name: "zz Sample Name")])
        #expect(model.name == "zz Sample Name")
    }

    @Test func emptyNameShowsTheRightMessageAndSavesNothing() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        await model.submit()
        #expect(model.problem == .invalid(.empty))
        #expect(model.problemMessage == "Please enter a name.")

        model.updateName("    ")
        await model.submit()
        #expect(model.problem == .invalid(.empty))
        #expect(await store.saveCount == 0)
        #expect(recorder.profiles.isEmpty)
    }

    @Test func controlCharactersShowTheRightMessageAndSaveNothing() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.updateName("zz\nSample")
        await model.submit()
        #expect(model.problem == .invalid(.invalidCharacters))
        #expect(model.problemMessage == "Please remove special characters.")
        #expect(await store.saveCount == 0)
        #expect(recorder.profiles.isEmpty)
    }

    @Test func typingBeyondTheLimitIsCutOffAndSaysSo() {
        let model = makeModel(store: OnboardingStubProfileStore(), recorder: SavedRecorder())
        let atLimit = String(repeating: "z", count: ProfileNameValidator.maximumLength)
        model.updateName(atLimit)
        #expect(model.name == atLimit)
        #expect(model.problem == nil)

        model.updateName(atLimit + "z")
        #expect(model.name == atLimit)
        #expect(model.problem == .invalid(.tooLong))
        #expect(model.problemMessage == "Names can be up to 40 characters.")
    }

    @Test func aNameOfExactlyTheMaximumLengthIsAccepted() async {
        let store = OnboardingStubProfileStore()
        let model = makeModel(store: store, recorder: SavedRecorder())
        let atLimit = String(repeating: "z", count: ProfileNameValidator.maximumLength)
        model.updateName(atLimit)
        await model.submit()
        #expect(await store.savedProfile == UserProfile(name: atLimit))
    }

    @Test func editingClearsTheMessage() async {
        let model = makeModel(store: OnboardingStubProfileStore(), recorder: SavedRecorder())
        await model.submit()
        #expect(model.problem != nil)
        model.updateName("z")
        #expect(model.problem == nil)
    }

    @Test func saveFailureIsSurfacedKeepsTheTextAndDoesNotReport() async {
        let store = OnboardingStubProfileStore(saveError: .writeFailed)
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.updateName("zz Sample")
        await model.submit()
        #expect(model.problem == .saveFailed(.writeFailed))
        #expect(model.problemMessage == "Your name could not be saved on this device. Please try again.")
        #expect(model.name == "zz Sample")
        #expect(model.isSaving == false)
        #expect(recorder.profiles.isEmpty)
        #expect(await store.savedProfile == nil)
    }

    @Test func aCorruptExistingFileSurfacesAsASaveFailure() async {
        let store = OnboardingStubProfileStore(saveError: .corrupt)
        let model = makeModel(store: store, recorder: SavedRecorder())
        model.updateName("zz Sample")
        await model.submit()
        #expect(model.problem == .saveFailed(.corrupt))
    }

    @Test func retryingAfterAFailedSaveCanSucceed() async {
        let store = FailOnceProfileStore()
        let recorder = SavedRecorder()
        let model = NameEntryViewModel(store: store) { recorder.record($0) }
        model.updateName("zz Sample")
        await model.submit()
        #expect(model.problem == .saveFailed(.writeFailed))
        await model.submit()
        #expect(model.problem == nil)
        #expect(recorder.profiles == [UserProfile(name: "zz Sample")])
    }
}

/// Fails the first save, then succeeds.
private actor FailOnceProfileStore: ProfileStore {
    private var hasFailed = false

    func load() async throws(ProfileStoreError) -> UserProfile? { nil }

    func save(_ profile: UserProfile) async throws(ProfileStoreError) {
        if !hasFailed {
            hasFailed = true
            throw .writeFailed
        }
    }

    func erase() async throws(ProfileStoreError) {}
}
