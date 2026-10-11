import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
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
    /// Where this course's final-exam attempts are kept (DECISIONS 041). Separate from `store`: an exam never
    /// writes a review record, but Reset progress erases both.
    public let examResults: any ExamResultStore
    /// The course's final-exam paper, or `nil` while it has none (the papers are written after Level 8 is
    /// reviewed). With `nil`, Home shows no exam entry.
    public let examPaper: ExamPaper?

    public init(
        catalog: Catalog,
        language: CourseLanguage,
        store: any ProgressStore,
        scheduler: any Scheduler,
        now: @escaping @Sendable () -> Date,
        examResults: any ExamResultStore = InMemoryExamResultStore(),
        examPaper: ExamPaper? = nil
    ) {
        self.catalog = catalog
        self.language = language
        self.store = store
        self.scheduler = scheduler
        self.now = now
        self.examResults = examResults
        self.examPaper = examPaper
    }
}
