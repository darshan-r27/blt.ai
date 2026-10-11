import BLTCatalog
import BLTCore
import Foundation

/// Reads a course's exam paper (`content/<language>/exam/final.json`, DECISIONS 046) into an `ExamPaper`.
///
/// The file looks like a lesson file: `scenarioId`, `language`, `title`, `subtitle` and an `items` list of NEW
/// sentences, each an ordinary lesson item plus `examLevel` (1 to 8, the level whose patterns it tests). A
/// `fromLessons` list names the items taken from the lessons by id; their level is the level of their lesson.
/// The new items go through `ContentLoader`, so they obey every lesson-item rule, and then they must not repeat
/// any lesson prompt or answer. Nothing is repaired: a paper with any problem is refused whole, so a learner is
/// never given a short or odd exam.
public struct ExamPaperLoader: Sendable {
    private let loader: ContentLoader
    private let blueprint: ExamBlueprint?

    /// `blueprint` is `nil` for no shape check (small test papers); the app passes `.syllabus`.
    public init(blueprint: ExamBlueprint? = nil, loader: ContentLoader = ContentLoader()) {
        self.blueprint = blueprint
        self.loader = loader
    }

    /// `catalog` is the course's lessons, which `fromLessons` ids refer to.
    public func load(file: URL, catalog: Catalog, language: CourseLanguage) -> Result<ExamPaper, ExamPaperLoadFailure> {
        guard file.isFileURL, let data = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            return .failure(ExamPaperLoadFailure(issues: [.unreadable]))
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(ExamPaperLoadFailure(issues: [.malformed]))
        }
        let exam = loader.load(files: [file], expectedLanguage: language)
        guard exam.issues.isEmpty, let scenario = exam.scenarios.first else {
            return .failure(ExamPaperLoadFailure(issues: [.invalidItems(count: max(exam.issues.count, 1))]))
        }

        var issues: [ExamPaperIssue] = []
        var sources: [ExamQuestionSource] = []
        let levels = examLevels(in: object)
        for item in scenario.items {
            if let level = levels[item.id.rawValue], (1...8).contains(level) {
                sources.append(ExamQuestionSource(item: item, level: level))
            } else {
                issues.append(.badExamLevel(item.id))
            }
        }
        let fromLessons = lessonSources(object["fromLessons"], catalog: catalog, issues: &issues)
        issues.append(contentsOf: repeats(of: catalog, in: scenario.items))
        sources.append(contentsOf: fromLessons.map(\.source))
        if let blueprint {
            let newSources = sources.filter { $0.item.scenarioID == scenario.id }
            issues.append(contentsOf: check(blueprint, newSources: newSources, lessonSources: fromLessons))
        }
        guard issues.isEmpty else { return .failure(ExamPaperLoadFailure(issues: issues)) }
        return .success(ExamPaper(sources: sources))
    }

    // MARK: Reading the file

    /// `examLevel` per new item id. Items without a whole-number level are absent, so they are reported.
    private func examLevels(in object: [String: Any]) -> [String: Int] {
        var levels: [String: Int] = [:]
        for case let entry as [String: Any] in (object["items"] as? [Any]) ?? [] {
            if let id = entry["id"] as? String, let level = entry["examLevel"] as? Int { levels[id] = level }
        }
        return levels
    }

    private struct LessonSource {
        let source: ExamQuestionSource
        let lesson: ScenarioID
    }

    private func lessonSources(_ value: Any?, catalog: Catalog, issues: inout [ExamPaperIssue]) -> [LessonSource] {
        var found: [LessonSource] = []
        var seen: Set<String> = []
        for case let id as String in (value as? [Any]) ?? [] {
            let itemID = ItemID(rawValue: id)
            guard seen.insert(id).inserted else {
                issues.append(.duplicateLessonItem(itemID))
                continue
            }
            guard let scenario = catalog.scenarios.first(where: { $0.items.contains { $0.id == itemID } }),
                  let item = scenario.items.first(where: { $0.id == itemID }) else {
                issues.append(.unknownLessonItem(itemID))
                continue
            }
            let source = ExamQuestionSource(item: item, level: scenario.level?.number)
            found.append(LessonSource(source: source, lesson: scenario.id))
        }
        return found
    }

    // MARK: Rules

    private func repeats(of catalog: Catalog, in newItems: [Item]) -> [ExamPaperIssue] {
        let lessonItems = catalog.scenarios.flatMap(\.items)
        let prompts = Set(lessonItems.map { Self.key($0.sourcePrompt) })
        let answers = Set(lessonItems.map { Self.key($0.canonical) })
        return newItems
            .filter { prompts.contains(Self.key($0.sourcePrompt)) || answers.contains(Self.key($0.canonical)) }
            .map { .repeatsALesson($0.id) }
    }

    /// Lowercase letters and digits only, the same comparison the duplicate rule uses across a course.
    private static func key(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private func check(
        _ blueprint: ExamBlueprint,
        newSources: [ExamQuestionSource],
        lessonSources: [LessonSource]
    ) -> [ExamPaperIssue] {
        var issues: [ExamPaperIssue] = []
        for row in blueprint.rows {
            let lessons = lessonSources.filter { $0.source.level == row.level }.count
            let new = newSources.filter { $0.level == row.level }.count
            if lessons != row.fromLessons { issues.append(.blueprint(level: row.level, rule: .lessonQuestionCount)) }
            if new != row.newSentences { issues.append(.blueprint(level: row.level, rule: .newSentenceCount)) }
        }
        let choices = (newSources + lessonSources.map(\.source)).filter { $0.item.registerVariant != nil }.count
        if choices < blueprint.minimumRegisterChoices {
            issues.append(.blueprint(level: nil, rule: .registerChoiceCount))
        }
        let perLesson = Dictionary(grouping: lessonSources, by: \.lesson).values
        if perLesson.contains(where: { $0.count > blueprint.maximumPerLesson }) {
            issues.append(.blueprint(level: nil, rule: .lessonUsedTooOften))
        }
        return issues
    }
}
