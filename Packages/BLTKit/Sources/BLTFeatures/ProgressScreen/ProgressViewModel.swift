import BLTProgress
import Foundation
import Observation

/// Loads the figures for the Progress screen. Read-only: it never writes to the store.
@MainActor
@Observable
final class ProgressViewModel {
    private(set) var summary: ProgressSummary?
    private(set) var loadError: ProgressStoreError?
    private(set) var hasLoaded = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
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
