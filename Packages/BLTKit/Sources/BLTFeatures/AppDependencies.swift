import BLTCatalog
import BLTCore
import BLTProgress
import Foundation

/// What the screens need to run one course. Built by the composition root for one language at a time
/// (DECISIONS 043): the catalog holds that language's lessons and the store holds that language's progress.
public struct AppDependencies: Sendable {
    public let catalog: Catalog
    /// The course these dependencies were built for. Required: nothing here ever assumes one.
    public let language: CourseLanguage
    public let store: any ProgressStore
    public let scheduler: any Scheduler
    public let now: @Sendable () -> Date

    public init(
        catalog: Catalog,
        language: CourseLanguage,
        store: any ProgressStore,
        scheduler: any Scheduler,
        now: @escaping @Sendable () -> Date
    ) {
        self.catalog = catalog
        self.language = language
        self.store = store
        self.scheduler = scheduler
        self.now = now
    }
}
