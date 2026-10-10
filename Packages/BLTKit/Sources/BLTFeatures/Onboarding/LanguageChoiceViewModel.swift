import BLTCore
import BLTProgress
import Foundation
import Observation

/// Drives the language step: nothing is chosen until the learner picks one, Continue saves it.
///
/// The app never assumes a language (DECISIONS 043), so `selection` starts empty even though
/// there are only two courses. A failed save keeps the learner here with their choice intact.
@MainActor
@Observable
final class LanguageChoiceViewModel {
    /// Why the last Continue did not finish.
    enum Problem: Equatable, Sendable {
        case saveFailed(ProfileStoreError)
    }

    let profile: UserProfile
    /// The languages on offer, in the order shown.
    let options: [CourseLanguage] = CourseLanguage.allCases
    private(set) var selection: CourseLanguage?
    private(set) var problem: Problem?
    private(set) var isSaving = false

    private let store: any ProfileStore
    private let onSaved: @MainActor (UserProfile) -> Void

    /// `onSaved` runs once, after the profile has been written, with exactly what was written.
    init(
        store: any ProfileStore,
        profile: UserProfile,
        onSaved: @escaping @MainActor (UserProfile) -> Void
    ) {
        self.store = store
        self.profile = profile
        self.onSaved = onSaved
    }

    /// Continue is available once a language is chosen, and not while a save is running.
    var canContinue: Bool { selection != nil && !isSaving }

    /// Calm, plain wording for the current problem, or `nil` when there is none.
    var problemMessage: String? {
        switch problem {
        case nil: nil
        case .saveFailed: "Your choice could not be saved on this device. Please try again."
        }
    }

    /// Choosing again replaces the earlier choice and clears any message.
    func select(_ language: CourseLanguage) {
        guard !isSaving else { return }
        selection = language
        problem = nil
    }

    /// Saves the profile with the chosen language, then reports. Does nothing without a choice or while
    /// a save is already running.
    func submit() async {
        guard let choice = selection, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let updated = profile.withLearningLanguage(choice)
        do throws(ProfileStoreError) {
            try await store.save(updated)
        } catch {
            problem = .saveFailed(error)
            return
        }
        problem = nil
        onSaved(updated)
    }
}
