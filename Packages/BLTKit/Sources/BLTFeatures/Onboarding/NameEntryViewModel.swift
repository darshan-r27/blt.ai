import BLTProgress
import Foundation
import Observation

/// Drives one name field: the first-launch Name entry screen and the Change name sheet in Settings.
///
/// Validation happens when the user submits, never by disabling a button. What is saved is the
/// validated name (trimmed, inner whitespace collapsed), not the raw text. A failed save keeps the
/// user where they are with their text intact.
@MainActor
@Observable
final class NameEntryViewModel: Identifiable {
    /// Why the last submit did not finish.
    enum Problem: Equatable, Sendable {
        case invalid(ProfileNameError)
        case saveFailed(ProfileStoreError)
    }

    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// The text in the field.
    private(set) var name: String
    private(set) var problem: Problem?
    private(set) var isSaving = false

    private let store: any ProfileStore
    private let onSaved: @MainActor (UserProfile) -> Void

    /// `onSaved` runs once, after the profile has been written, with exactly what was written.
    init(
        store: any ProfileStore,
        initialName: String = "",
        onSaved: @escaping @MainActor (UserProfile) -> Void
    ) {
        self.store = store
        name = initialName
        self.onSaved = onSaved
    }

    /// Calm, plain wording for the current problem, or `nil` when there is none.
    var problemMessage: String? {
        switch problem {
        case nil: nil
        case .invalid(.empty): "Please enter a name."
        case .invalid(.tooLong): "Names can be up to \(ProfileNameValidator.maximumLength) characters."
        case .invalid(.invalidCharacters): "Please remove special characters."
        case .saveFailed: "Your name could not be saved on this device. Please try again."
        }
    }

    /// Called as the user types. Text beyond `ProfileNameValidator.maximumLength` is cut off and the
    /// length message is shown at once, so a long paste is never shortened silently.
    func updateName(_ text: String) {
        let limited = String(text.prefix(ProfileNameValidator.maximumLength))
        name = limited
        problem = limited.count < text.count ? .invalid(.tooLong) : nil
    }

    /// Validates, saves, then reports. Does nothing while a save is already running.
    func submit() async {
        guard !isSaving else { return }
        let validName: String
        switch ProfileNameValidator.validate(name) {
        case .failure(let error):
            problem = .invalid(error)
            return
        case .success(let value):
            validName = value
        }

        isSaving = true
        defer { isSaving = false }
        let profile = UserProfile(name: validName)
        do throws(ProfileStoreError) {
            try await store.save(profile)
        } catch {
            problem = .saveFailed(error)
            return
        }
        problem = nil
        name = validName
        onSaved(profile)
    }
}
