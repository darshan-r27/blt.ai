import BLTProgress
import Foundation
import Observation

/// Decides what the app shows first: onboarding, a problem screen, or Home.
///
/// A profile that cannot be read is never replaced behind the user's back. `.corrupt` and
/// `.unsupportedSchemaVersion` lead to a screen that offers Start over, which erases the profile
/// file (and only that file) after an explicit confirmation. `.unreadable` offers Try again.
@MainActor
@Observable
public final class ProfileGateViewModel {
    public enum State: Equatable {
        case loading
        /// No profile has been saved yet.
        case needsOnboarding
        case ready(UserProfile)
        case loadFailed(ProfileStoreError)
    }

    public enum OnboardingStep: Equatable {
        case intro
        case nameEntry
    }

    public private(set) var state: State = .loading
    public private(set) var onboardingStep: OnboardingStep = .intro
    /// Set when Start over was confirmed but the profile file could not be erased.
    public private(set) var startOverError: ProfileStoreError?
    public private(set) var isErasing = false
    /// Bound to the confirmation alert. Setting it is not a confirmation; only `confirmStartOver()` erases.
    public var isConfirmingStartOver = false

    private let store: any ProfileStore

    public init(store: any ProfileStore) {
        self.store = store
    }

    /// Only a damaged or newer-than-supported file can be fixed by erasing it. A transient read failure
    /// should be retried instead.
    public var canOfferStartOver: Bool {
        switch state {
        case .loadFailed(.corrupt), .loadFailed(.unsupportedSchemaVersion): true
        default: false
        }
    }

    public func load() async {
        do throws(ProfileStoreError) {
            if let profile = try await store.load() {
                state = .ready(profile)
            } else {
                beginOnboarding()
            }
        } catch {
            state = .loadFailed(error)
        }
    }

    /// Try again after an `.unreadable` failure.
    public func retry() async {
        state = .loading
        await load()
    }

    public func showNameEntry() {
        onboardingStep = .nameEntry
    }

    /// A name field wired to this gate: saving it moves on to Home.
    public func makeNameEntryViewModel() -> NameEntryViewModel {
        NameEntryViewModel(store: store) { [weak self] profile in
            self?.profileDidChange(profile)
        }
    }

    /// The saved profile is now `profile`: after onboarding, or after Change name in Settings.
    public func profileDidChange(_ profile: UserProfile) {
        state = .ready(profile)
    }

    /// Step one of Start over: ask the user. Erases nothing.
    public func requestStartOver() {
        startOverError = nil
        isConfirmingStartOver = true
    }

    public func cancelStartOver() {
        isConfirmingStartOver = false
    }

    /// Step two of Start over: wired only to the alert's confirming button. Erases the profile file and
    /// goes to onboarding. Saved progress is a different store and is not touched.
    public func confirmStartOver() async {
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
