import BLTProgress
import Foundation
import Observation

/// Drives Settings: the content-review statement, the saved name with Change name, and Reset progress.
/// Reset erases progress only; the name is a different store and is never touched here.
@MainActor
@Observable
public final class SettingsViewModel {
    public enum ResetOutcome: Equatable {
        case succeeded
        case failed(ProgressStoreError)
    }

    public let reviewedCount: Int
    public let totalCount: Int
    /// True only when the catalog has items and every one is marked `reviewed` (a native Tamil speaker
    /// checked it). The statement below follows the data, so the app never claims more than the content says.
    public var allContentReviewed: Bool { totalCount > 0 && reviewedCount == totalCount }

    /// The "About the content" statement for the current content.
    public var contentStatement: String {
        allContentReviewed
            ? "Every lesson was checked by a native Tamil speaker before it was added to the app."
            : "These lessons were drafted by an AI. Each item shows its review status, "
                + "and an item counts as reviewed only after a native Tamil speaker has checked it."
    }

    public private(set) var resetOutcome: ResetOutcome?
    public private(set) var isResetting = false
    /// The saved display name. Updated as soon as Change name saves.
    public private(set) var profileName: String
    /// Non-nil exactly while the Change name sheet is open.
    public private(set) var nameEditor: NameEntryViewModel?
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    public var isConfirmingReset = false

    private let store: any ProgressStore
    private let profileStore: any ProfileStore
    private let onDidReset: @MainActor () -> Void
    private let onDidChangeName: @MainActor (UserProfile) -> Void

    /// `onDidReset` lets the owner of Home reload after a successful reset; `onDidChangeName` lets it show
    /// the new name straight away.
    public init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        profileName: String,
        onDidReset: @escaping @MainActor () -> Void = {},
        onDidChangeName: @escaping @MainActor (UserProfile) -> Void = { _ in }
    ) {
        reviewedCount = dependencies.catalog.reviewedItemCount
        totalCount = dependencies.catalog.totalItemCount
        store = dependencies.store
        self.profileStore = profileStore
        self.profileName = profileName
        self.onDidReset = onDidReset
        self.onDidChangeName = onDidChangeName
    }

    /// Opens the Change name sheet with the current name in the field. Saves nothing.
    public func beginChangeName() {
        nameEditor = NameEntryViewModel(store: profileStore, initialName: profileName) { [weak self] profile in
            self?.nameDidSave(profile)
        }
    }

    /// Closes the sheet. Whatever was typed is discarded and the saved name is unchanged.
    public func cancelChangeName() {
        nameEditor = nil
    }

    private func nameDidSave(_ profile: UserProfile) {
        profileName = profile.name
        nameEditor = nil
        onDidChangeName(profile)
    }

    /// Step one of Reset: ask the user. Erases nothing.
    public func requestReset() {
        resetOutcome = nil
        isConfirmingReset = true
    }

    public func cancelReset() {
        isConfirmingReset = false
    }

    /// Step two of Reset: wired only to the dialog's destructive button.
    public func confirmReset() async {
        isConfirmingReset = false
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        do throws(ProgressStoreError) {
            try await store.eraseAll()
        } catch {
            resetOutcome = .failed(error)
            return
        }
        resetOutcome = .succeeded
        onDidReset()
    }
}
