/// The shape a full exam paper must have (docs/COURSE_SYLLABUS.md section 6, DECISIONS 046). The loader checks a
/// paper against a blueprint only when given one, so small test papers do not need a full 100 questions.
public struct ExamBlueprint: Sendable, Equatable {
    public enum Rule: Sendable, Equatable {
        case lessonQuestionCount
        case newSentenceCount
        case registerChoiceCount
        case lessonUsedTooOften
    }

    public struct Row: Sendable, Equatable {
        public let level: Int
        public let fromLessons: Int
        public let newSentences: Int

        public init(level: Int, fromLessons: Int, newSentences: Int) {
            self.level = level
            self.fromLessons = fromLessons
            self.newSentences = newSentences
        }
    }

    public let rows: [Row]
    /// At least this many questions must carry a register choice (an item with a `registerVariant`).
    public let minimumRegisterChoices: Int
    /// No lesson may supply more questions than this.
    public let maximumPerLesson: Int

    public init(rows: [Row], minimumRegisterChoices: Int, maximumPerLesson: Int) {
        self.rows = rows
        self.minimumRegisterChoices = minimumRegisterChoices
        self.maximumPerLesson = maximumPerLesson
    }

    /// The table in the syllabus: 30 questions from the lessons, 70 new sentences, 100 in all.
    public static let syllabus = ExamBlueprint(
        rows: [
            Row(level: 1, fromLessons: 4, newSentences: 4),
            Row(level: 2, fromLessons: 4, newSentences: 6),
            Row(level: 3, fromLessons: 4, newSentences: 8),
            Row(level: 4, fromLessons: 4, newSentences: 8),
            Row(level: 5, fromLessons: 4, newSentences: 10),
            Row(level: 6, fromLessons: 4, newSentences: 10),
            Row(level: 7, fromLessons: 3, newSentences: 13),
            Row(level: 8, fromLessons: 3, newSentences: 11)
        ],
        minimumRegisterChoices: 40,
        maximumPerLesson: 2
    )
}
