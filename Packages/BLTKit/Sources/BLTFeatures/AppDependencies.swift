import BLTCatalog
import BLTProgress
import Foundation

public struct AppDependencies: Sendable {
    public let catalog: Catalog
    public let store: any ProgressStore
    public let scheduler: any Scheduler
    public let now: @Sendable () -> Date

    public init(
        catalog: Catalog,
        store: any ProgressStore,
        scheduler: any Scheduler,
        now: @escaping @Sendable () -> Date
    ) {
        self.catalog = catalog
        self.store = store
        self.scheduler = scheduler
        self.now = now
    }
}
