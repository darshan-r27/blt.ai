import BLTProgress
import Foundation
import Observation

/// Drives Settings: the content-review statement and the one action, Reset progress.
@MainActor
@Observable
public final class SettingsViewModel {
    public enum ResetOutcome: Equatable {
        case succeeded
        case failed(ProgressStoreError)
    }

    public let reviewedCount: Int
    public let totalCount: Int
    public private(set) var resetOutcome: ResetOutcome?
    public private(set) var isResetting = false
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    public var isConfirmingReset = false

    private let store: any ProgressStore
    private let onDidReset: @MainActor () -> Void

    /// `onDidReset` lets the owner of Home reload after a successful reset.
    public init(dependencies: AppDependencies, onDidReset: @escaping @MainActor () -> Void = {}) {
        reviewedCount = dependencies.catalog.reviewedItemCount
        totalCount = dependencies.catalog.totalItemCount
        store = dependencies.store
        self.onDidReset = onDidReset
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
