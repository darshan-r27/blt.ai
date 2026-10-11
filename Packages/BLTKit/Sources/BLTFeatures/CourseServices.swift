/// Everything the app needs to run one language's course: its dependencies, and the importer that
/// stores lessons for that language only (`nil` hides the Lessons section in Settings).
///
/// The composition root builds one of these per language on request (`RootView.init(makeCourse:)`), so the
/// language the learner chose, which is only known once the profile has loaded, picks the catalog, the
/// progress file and the imported-lessons folder.
public struct CourseServices: Sendable {
    public let dependencies: AppDependencies
    public let lessonImporter: (any LessonImporting)?

    public init(dependencies: AppDependencies, lessonImporter: (any LessonImporting)?) {
        self.dependencies = dependencies
        self.lessonImporter = lessonImporter
    }
}
