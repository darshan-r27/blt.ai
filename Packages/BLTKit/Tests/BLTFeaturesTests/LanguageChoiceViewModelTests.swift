import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// Collects what `onSaved` was called with.
@MainActor
private final class SavedRecorder {
    private(set) var profiles: [UserProfile] = []
    func record(_ profile: UserProfile) { profiles.append(profile) }
}

@MainActor
struct LanguageChoiceViewModelTests {
    private let profile = UserProfile(name: "zz Sample")

    private func makeModel(store: OnboardingStubProfileStore, recorder: SavedRecorder) -> LanguageChoiceViewModel {
        LanguageChoiceViewModel(store: store, profile: profile) { recorder.record($0) }
    }

    @Test func startsWithNothingChosenAndContinueUnavailable() {
        let model = makeModel(store: OnboardingStubProfileStore(), recorder: SavedRecorder())
        #expect(model.selection == nil)
        #expect(model.canContinue == false)
        #expect(model.problemMessage == nil)
    }

    @Test func continueDoesNothingUntilAChoiceIsMade() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        await model.submit()
        #expect(await store.saveCount == 0)
        #expect(recorder.profiles.isEmpty)
    }

    @Test func bothLanguagesAreOnOfferAndSelectable() {
        let model = makeModel(store: OnboardingStubProfileStore(), recorder: SavedRecorder())
        #expect(model.options == [.tamil, .telugu])
        for language in model.options {
            model.select(language)
            #expect(model.selection == language)
            #expect(model.canContinue)
        }
    }

    @Test func choosingTwiceKeepsTheLastChoice() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.select(.tamil)
        model.select(.telugu)
        #expect(model.selection == .telugu)
        await model.submit()
        #expect(await store.savedProfile == UserProfile(name: "zz Sample", learningLanguage: .telugu))
    }

    @Test func savedProfileKeepsTheNameAndCarriesTheChosenLanguage() async {
        let store = OnboardingStubProfileStore()
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.select(.tamil)
        await model.submit()
        let expected = UserProfile(name: "zz Sample", learningLanguage: .tamil)
        #expect(await store.savedProfile == expected)
        #expect(recorder.profiles == [expected])
        #expect(model.problem == nil)
    }

    @Test func aFailedSaveShowsACalmMessageKeepsTheChoiceAndReportsNothing() async {
        let store = OnboardingStubProfileStore(saveError: .writeFailed)
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.select(.telugu)
        await model.submit()
        #expect(model.problem == .saveFailed(.writeFailed))
        #expect(model.problemMessage == "Your choice could not be saved on this device. Please try again.")
        #expect(model.selection == .telugu)
        #expect(model.canContinue)
        #expect(recorder.profiles.isEmpty)
    }

    @Test func retryingAfterAFailureSucceedsAndClearsTheMessage() async {
        let store = OnboardingStubProfileStore(failingSaves: 1)
        let recorder = SavedRecorder()
        let model = makeModel(store: store, recorder: recorder)
        model.select(.telugu)
        await model.submit()
        #expect(model.problem != nil)

        await model.submit()
        #expect(model.problem == nil)
        #expect(recorder.profiles == [UserProfile(name: "zz Sample", learningLanguage: .telugu)])
        #expect(await store.saveCount == 2)
    }

    @Test func choosingAgainClearsTheMessage() async {
        let store = OnboardingStubProfileStore(saveError: .writeFailed)
        let model = makeModel(store: store, recorder: SavedRecorder())
        model.select(.tamil)
        await model.submit()
        #expect(model.problemMessage != nil)
        model.select(.telugu)
        #expect(model.problemMessage == nil)
    }
}
