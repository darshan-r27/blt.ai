import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

/// Records the profiles the owner of Settings was told about.
@MainActor
private final class LanguageCounter {
    private(set) var profiles: [UserProfile] = []
    func record(_ profile: UserProfile) { profiles.append(profile) }
}

@MainActor
private func makeModel(
    language: CourseLanguage? = nil,
    profileStore: any ProfileStore = InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
    allReviewed: Bool = false,
    onDidChangeLanguage: @escaping @MainActor (UserProfile) -> Void = { _ in }
) -> SettingsViewModel {
    SettingsViewModel(
        dependencies: makeDependencies(allReviewed: allReviewed),
        profileStore: profileStore,
        profileName: "zz Sample",
        learningLanguage: language,
        onDidChangeLanguage: onDidChangeLanguage
    )
}

private func makeDependencies(allReviewed: Bool) -> AppDependencies {
    let status: ReviewStatus = allReviewed ? .reviewed : .unreviewed
    let item = Item(
        id: ItemID(rawValue: "zz-s1"),
        scenarioID: ScenarioID(rawValue: "zz-s"),
        sourcePrompt: "zz prompt",
        register: .neutral,
        addressee: .any,
        canonical: "zz canonical",
        acceptedAnswers: ["zz canonical", "zz alt a", "zz alt b"],
        registerVariant: nil,
        distractors: ["zz wrong a", "zz wrong b", "zz wrong c"],
        tokens: [Token(word: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: status
    )
    let scenario = Scenario(
        id: ScenarioID(rawValue: "zz-s"),
        title: "zz S",
        subtitle: "zz sub",
        romanisationNote: nil,
        items: [item],
        language: .tamil
    )
    return AppDependencies(
        catalog: Catalog(scenarios: [scenario], issues: []),
        language: .tamil,
        store: InMemoryProgressStore(initial: .empty),
        scheduler: SM2Scheduler(),
        now: { Date(timeIntervalSince1970: 1_000_000) }
    )
}

@MainActor
struct SettingsLanguageTests {
    // MARK: The row

    @Test func rowShowsNotChosenWhenNoLanguageIsSupplied() {
        let model = makeModel()
        #expect(model.learningLanguage == nil)
        #expect(model.learningLanguageLabel == "Not chosen")
    }

    @Test func rowShowsTheCurrentLanguageName() {
        #expect(makeModel(language: .tamil).learningLanguageLabel == "Tamil")
        #expect(makeModel(language: .telugu).learningLanguageLabel == "Telugu")
    }

    @Test func bothLanguagesAreOffered() {
        #expect(makeModel().languageOptions == [.tamil, .telugu])
    }

    @Test func openingTheChoiceSavesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let model = makeModel(language: .tamil, profileStore: profileStore)
        model.toggleLanguageChoice()
        #expect(model.isChoosingLanguage)
        #expect(model.pendingLanguage == nil)
        #expect(await profileStore.saveCount == 0)
    }

    // MARK: Switching

    @Test func choosingTheOtherLanguageAsksFirstAndSavesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let model = makeModel(language: .tamil, profileStore: profileStore)
        model.toggleLanguageChoice()
        model.chooseLanguage(.telugu)
        #expect(model.isConfirmingLanguageChange)
        #expect(model.pendingLanguage == .telugu)
        #expect(model.isChoosingLanguage == false)
        #expect(model.languageChangeTitle == "Switch to Telugu?")
        #expect(model.languageChangeMessage.contains("keeps its own progress"))
        #expect(model.languageChangeMessage.contains("switch back"))
        #expect(model.learningLanguage == .tamil)
        #expect(await profileStore.saveCount == 0)
    }

    @Test func confirmingSavesTheNewLanguageKeepsTheNameAndTellsTheOwnerOnce() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Stored", learningLanguage: .tamil))
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        let expected = UserProfile(name: "zz Stored", learningLanguage: .telugu)
        #expect(await profileStore.savedProfile == expected)
        #expect(await profileStore.saveCount == 1)
        #expect(counter.profiles == [expected])
        #expect(model.learningLanguage == .telugu)
        #expect(model.learningLanguageLabel == "Telugu")
        #expect(model.isConfirmingLanguageChange == false)
        #expect(model.languageChangeFailed == false)
    }

    @Test func choosingALanguageWhenNoneWasChosenCanBeConfirmed() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample"))
        let counter = LanguageCounter()
        let model = makeModel(profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.tamil)
        await model.confirmLanguageChange()
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Sample", learningLanguage: .tamil))
        #expect(counter.profiles.count == 1)
        #expect(model.learningLanguage == .tamil)
    }

    @Test func cancellingTheConfirmationChangesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        model.cancelLanguageChange()
        #expect(model.isConfirmingLanguageChange == false)
        #expect(model.pendingLanguage == nil)
        #expect(model.learningLanguage == .tamil)
        #expect(await profileStore.saveCount == 0)
        #expect(counter.profiles.isEmpty)
        // Confirming with nothing pending is also a no-op.
        await model.confirmLanguageChange()
        #expect(await profileStore.saveCount == 0)
    }

    @Test func dismissingTheConfirmationSavesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let model = makeModel(language: .tamil, profileStore: profileStore)
        model.chooseLanguage(.telugu)
        model.isConfirmingLanguageChange = false
        #expect(model.isConfirmingLanguageChange == false)
        #expect(model.learningLanguage == .tamil)
        #expect(await profileStore.saveCount == 0)
    }

    /// The system sets the dialog's binding to false as the Switch button is tapped, before or as its action runs.
    /// The switch must still happen (found by the UI test that switches language in Settings).
    @Test func switchStillHappensWhenTheDialogIsDismissedAsSwitchIsTapped() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        model.isConfirmingLanguageChange = false
        await model.confirmLanguageChange()
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Sample", learningLanguage: .telugu))
        #expect(counter.profiles.count == 1)
        #expect(model.learningLanguage == .telugu)
    }

    @Test func choosingTheCurrentLanguageDoesNothing() async {
        let profileStore = OnboardingStubProfileStore(profile: UserProfile(name: "zz Sample", learningLanguage: .tamil))
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.toggleLanguageChoice()
        model.chooseLanguage(.tamil)
        #expect(model.isConfirmingLanguageChange == false)
        #expect(model.isChoosingLanguage == false)
        await model.confirmLanguageChange()
        #expect(await profileStore.saveCount == 0)
        #expect(counter.profiles.isEmpty)
        #expect(model.learningLanguage == .tamil)
    }

    @Test func failedSaveShowsAMessageAndChangesNothing() async {
        let profileStore = OnboardingStubProfileStore(
            profile: UserProfile(name: "zz Sample", learningLanguage: .tamil),
            saveError: .writeFailed
        )
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        #expect(model.languageChangeFailed)
        #expect(model.languageChangeFailureMessage.contains("nothing was changed"))
        #expect(model.learningLanguage == .tamil)
        #expect(counter.profiles.isEmpty)
        #expect(await profileStore.savedProfile == UserProfile(name: "zz Sample", learningLanguage: .tamil))
    }

    @Test func failedLoadShowsAMessageAndSavesNothing() async {
        let profileStore = OnboardingStubProfileStore(
            profile: UserProfile(name: "zz Sample", learningLanguage: .tamil),
            loadError: .unreadable
        )
        let counter = LanguageCounter()
        let model = makeModel(language: .tamil, profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        #expect(model.languageChangeFailed)
        #expect(await profileStore.saveCount == 0)
        #expect(counter.profiles.isEmpty)
        #expect(model.learningLanguage == .tamil)
    }

    @Test func missingStoredProfileIsAFailureNotAnInventedName() async {
        let profileStore = OnboardingStubProfileStore(profile: nil)
        let counter = LanguageCounter()
        let model = makeModel(profileStore: profileStore, onDidChangeLanguage: { counter.record($0) })
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        #expect(model.languageChangeFailed)
        #expect(await profileStore.saveCount == 0)
        #expect(counter.profiles.isEmpty)
    }

    @Test func aNewAttemptClearsTheFailureMessage() async {
        let profileStore = OnboardingStubProfileStore(
            profile: UserProfile(name: "zz Sample", learningLanguage: .tamil),
            saveError: .writeFailed
        )
        let model = makeModel(language: .tamil, profileStore: profileStore)
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        #expect(model.languageChangeFailed)
        model.chooseLanguage(.telugu)
        #expect(model.languageChangeFailed == false)
    }

    // MARK: Wording that names the language

    @Test func statementNamesEachLanguageWhenEveryItemIsReviewed() {
        let tamil = makeModel(language: .tamil, allReviewed: true)
        #expect(tamil.contentStatement
            == "Every lesson was checked by a native Tamil speaker before it was added to the app.")
        let telugu = makeModel(language: .telugu, allReviewed: true)
        #expect(telugu.contentStatement
            == "Every lesson was checked by a native Telugu speaker before it was added to the app.")
    }

    @Test func draftStatementNamesEachLanguage() {
        let tamil = makeModel(language: .tamil)
        #expect(tamil.contentStatement.contains("drafted by an AI"))
        #expect(tamil.contentStatement.hasSuffix("only after a native Tamil speaker has checked it."))
        let telugu = makeModel(language: .telugu)
        #expect(telugu.contentStatement.hasSuffix("only after a native Telugu speaker has checked it."))
    }

    @Test func statementWithNoLanguageKeepsTheOriginalWording() {
        #expect(makeModel(allReviewed: true).contentStatement
            == "Every lesson was checked by a native Tamil / Telugu speaker before it was added to the app.")
        #expect(makeModel().contentStatement.hasSuffix(
            "only after a native Tamil / Telugu speaker has checked it."
        ))
    }

    @Test func statementFollowsASwitchOnceSaved() async {
        let model = makeModel(
            language: .tamil,
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample", learningLanguage: .tamil)),
            allReviewed: true
        )
        model.chooseLanguage(.telugu)
        await model.confirmLanguageChange()
        #expect(model.contentStatement.contains("native Telugu speaker"))
    }

    @Test func resetWordingNamesEachLanguage() {
        let tamil = makeModel(language: .tamil)
        #expect(tamil.resetTitle == "Reset Tamil progress?")
        #expect(tamil.resetMessage.hasPrefix("This clears your Tamil progress."))
        #expect(tamil.resetMessage.contains("Your name and your other language's progress are kept."))
        #expect(tamil.resetMessage.contains("cannot be undone"))
        let telugu = makeModel(language: .telugu)
        #expect(telugu.resetTitle == "Reset Telugu progress?")
        #expect(telugu.resetMessage.hasPrefix("This clears your Telugu progress."))
    }

    @Test func resetWordingWithNoLanguageIsUnchanged() {
        let model = makeModel()
        #expect(model.resetTitle == "Reset all progress?")
        #expect(model.resetMessage == "This erases your review schedule and answer history on this device. "
            + "It cannot be undone. Your name is not erased.")
    }
}
