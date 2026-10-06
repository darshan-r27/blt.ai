import BLTCore
import BLTProgress
import Foundation
import Observation

/// Drives the Scenarios (home) screen.
///
/// A store error is shown, never repaired: nothing here resets, rewrites or deletes saved progress
/// unless the user goes through `requestReset()` and then `confirmReset()`.
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var scenarios: [ScenarioSummary] = []
    /// Set when the store could not be read. While set, `scenarios` is empty.
    public private(set) var loadError: ProgressStoreError?
    public private(set) var hasLoaded = false
    /// Set when a reset was confirmed but the store could not erase.
    public private(set) var resetError: ProgressStoreError?
    public private(set) var isResetting = false
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    public var isConfirmingReset = false

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// The greeting above the scenario cards. `name` is the validated display name (DECISIONS 030).
    public static func greeting(forName name: String) -> String {
        "Hi \(name)"
    }

    /// Only a damaged or newer-than-supported file can be fixed by erasing it. A transient read
    /// failure (`.unreadable`) should be retried instead, so no Reset is offered for it.
    public var canOfferReset: Bool {
        switch loadError {
        case .corrupt, .unsupportedSchemaVersion: true
        default: false
        }
    }

    public func load() async {
        do throws(ProgressStoreError) {
            let snapshot = try await dependencies.store.load()
            scenarios = dependencies.catalog.scenarios.map { ScenarioSummary(scenario: $0, snapshot: snapshot) }
            loadError = nil
        } catch {
            scenarios = []
            loadError = error
        }
        hasLoaded = true
    }

    /// Step one of Reset: ask the user. Erases nothing.
    public func requestReset() {
        resetError = nil
        isConfirmingReset = true
    }

    public func cancelReset() {
        isConfirmingReset = false
    }

    /// Step two of Reset: wired only to the dialog's destructive button. Erases the store, then
    /// reloads. If erasing fails the error is surfaced in `resetError` and the load error stays.
    public func confirmReset() async {
        isConfirmingReset = false
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        do throws(ProgressStoreError) {
            try await dependencies.store.eraseAll()
        } catch {
            resetError = error
            return
        }
        resetError = nil
        await load()
    }
}
