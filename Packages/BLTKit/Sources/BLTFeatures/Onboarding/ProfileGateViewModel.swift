import BLTProgress
import Foundation
import Observation

/// Decides what the app shows first: onboarding, the language step, a problem screen, or Home.
///
/// A profile that cannot be read is never replaced behind the user's back. `.corrupt` and
/// `.unsupportedSchemaVersion` lead to a screen that offers Start over, which erases the profile
/// file (and only that file) after an explicit confirmation. `.unreadable` offers Try again.
@MainActor
@Observable
final class ProfileGateViewModel {
    enum State: Equatable {
        case loading
        /// No profile has been saved yet.
        case needsOnboarding
        /// A profile with a name but no language: first launch after the name step, and every profile saved
        /// before the language existed. The app never assumes a language (DECISIONS 043).
        case needsLanguage(UserProfile)
        /// A profile with a name and a language.
        case ready(UserProfile)
        case loadFailed(ProfileStoreError)
    }

    enum OnboardingStep: Equatable {
        case intro
        case nameEntry
    }

    private(set) var state: State = .loading
    private(set) var onboardingStep: OnboardingStep = .intro
    /// Set when Start over was confirmed but the profile file could not be erased.
    private(set) var startOverError: ProfileStoreError?
    private(set) var isErasing = false
    /// Bound to the confirmation alert. Setting it is not a confirmation; only `confirmStartOver()` erases.
    var isConfirmingStartOver = false

    private let store: any ProfileStore

    init(store: any ProfileStore) {
        self.store = store
    }

    /// Only a damaged or newer-than-supported file can be fixed by erasing it. A transient read failure
    /// should be retried instead.
    var canOfferStartOver: Bool {
        switch state {
        case .loadFailed(.corrupt), .loadFailed(.unsupportedSchemaVersion): true
        default: false
        }
    }

    func load() async {
        do throws(ProfileStoreError) {
            if let profile = try await store.load() {
                profileDidChange(profile)
            } else {
                beginOnboarding()
            }
        } catch {
            state = .loadFailed(error)
        }
    }

    /// Try again after an `.unreadable` failure.
    func retry() async {
        state = .loading
        await load()
    }

    func showNameEntry() {
        onboardingStep = .nameEntry
    }

    /// A name field wired to this gate: saving it moves on to the language step.
    func makeNameEntryViewModel() -> NameEntryViewModel {
        NameEntryViewModel(store: store) { [weak self] profile in
            self?.profileDidChange(profile)
        }
    }

    /// The language choice for `profile`, wired to this gate: saving it moves on to Home.
    func makeLanguageChoiceViewModel(profile: UserProfile) -> LanguageChoiceViewModel {
        LanguageChoiceViewModel(store: store, profile: profile) { [weak self] saved in
            self?.profileDidChange(saved)
        }
    }

    /// The saved profile is now `profile`: after loading, after a step of onboarding, or after Change name
    /// in Settings. Home is shown only once the profile has a language.
    func profileDidChange(_ profile: UserProfile) {
        state = profile.learningLanguage == nil ? .needsLanguage(profile) : .ready(profile)
    }

    /// Step one of Start over: ask the user. Erases nothing.
    func requestStartOver() {
        startOverError = nil
        isConfirmingStartOver = true
    }

    func cancelStartOver() {
        isConfirmingStartOver = false
    }

    /// Step two of Start over: wired only to the alert's confirming button. Erases the profile file and
    /// goes to onboarding. Saved progress is a different store and is not touched.
    func confirmStartOver() async {
        isConfirmingStartOver = false
        guard canOfferStartOver, !isErasing else { return }
        isErasing = true
        defer { isErasing = false }
        do throws(ProfileStoreError) {
            try await store.erase()
        } catch {
            startOverError = error
            return
        }
        startOverError = nil
        beginOnboarding()
    }

    private func beginOnboarding() {
        onboardingStep = .intro
        state = .needsOnboarding
    }
}
