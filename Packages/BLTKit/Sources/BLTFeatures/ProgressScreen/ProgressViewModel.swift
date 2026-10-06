import BLTProgress
import Foundation
import Observation

/// Loads the figures for the Progress screen. Read-only: it never writes to the store.
@MainActor
@Observable
public final class ProgressViewModel {
    public private(set) var summary: ProgressSummary?
    public private(set) var loadError: ProgressStoreError?
    public private(set) var hasLoaded = false

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public func load() async {
        do throws(ProgressStoreError) {
            let snapshot = try await dependencies.store.load()
            summary = dependencies.catalog.progressSummary(snapshot: snapshot, now: dependencies.now())
            loadError = nil
        } catch {
            summary = nil
            loadError = error
        }
        hasLoaded = true
    }
}
