import BLTCore

/// One reason an exam paper file cannot be used (DECISIONS 046). Carries ids and numbers only, never text from
/// the file, so it is safe to log.
public enum ExamPaperIssue: Sendable, Equatable {
    /// The file could not be read.
    case unreadable
    /// The file is not valid JSON, or is not an object.
    case malformed
    /// The new-sentence items failed the same checks as lesson items (any `ContentIssue` at all).
    case invalidItems(count: Int)
    /// `fromLessons` names an item that is not in the course.
    case unknownLessonItem(ItemID)
    /// `fromLessons` names the same item twice.
    case duplicateLessonItem(ItemID)
    /// A new-sentence item has no `examLevel`, or one that is not a whole number from 1 to 8.
    case badExamLevel(ItemID)
    /// A new sentence repeats a lesson prompt or answer, so it is not new.
    case repeatsALesson(ItemID)
    /// The paper does not match the blueprint; `level` is `nil` for a whole-paper rule.
    case blueprint(level: Int?, rule: ExamBlueprint.Rule)
}

/// Why a paper was refused: every issue found, in the order found.
public struct ExamPaperLoadFailure: Error, Sendable, Equatable {
    public let issues: [ExamPaperIssue]

    public init(issues: [ExamPaperIssue]) {
        self.issues = issues
    }
}
