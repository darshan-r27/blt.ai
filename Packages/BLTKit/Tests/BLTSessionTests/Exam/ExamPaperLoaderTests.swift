import BLTCatalog
import BLTCore
import Foundation
import Testing

@testable import BLTSession

// The exam paper file (DECISIONS 046). Fake `zz` text only; files are written to a temporary folder.

private func lessonItem(_ id: String, scenario: String, withVariant: Bool = false) -> Item {
    Item(
        id: ItemID(rawValue: id),
        scenarioID: ScenarioID(rawValue: scenario),
        sourcePrompt: "zz lesson prompt \(id)",
        register: withVariant ? .respectful : .neutral,
        addressee: .any,
        canonical: "zz lesson canonical \(id)",
        acceptedAnswers: ["zz lesson canonical \(id)", "zz la \(id)", "zz lb \(id)"],
        registerVariant: withVariant ? "zz lesson variant \(id)" : nil,
        distractors: Array(["zz w1", "zz w2", "zz w3"].prefix(withVariant ? 2 : 3)),
        tokens: [Token(word: "zz", english: "zz gloss")],
        note: nil,
        reviewStatus: .unreviewed
    )
}

/// Lessons `zz-l<level>-a` and `-b`, two items each, for levels 1 to `levels`.
private func catalog(levels: Int = 2, withVariants: Bool = false) -> Catalog {
    let scenarios = (1...levels).flatMap { level in
        ["a", "b"].map { letter -> Scenario in
            let id = "zz-l\(level)-\(letter)"
            return Scenario(
                id: ScenarioID(rawValue: id),
                title: "zz \(id)",
                subtitle: "zz sub",
                romanisationNote: nil,
                items: (1...2).map { lessonItem("\(id)-i\($0)", scenario: id, withVariant: withVariants) },
                level: Level(number: level, title: "zz Level", position: letter == "a" ? 1 : 2),
                language: .tamil
            )
        }
    }
    return Catalog(scenarios: scenarios, issues: [])
}

private func newItemJSON(_ number: Int, level: Int?, prompt: String? = nil, variant: Bool = false) -> String {
    let levelPart = level.map { ",\n \"examLevel\": \($0)" } ?? ""
    let register = variant ? "respectful" : "neutral"
    let variantPart = variant ? "\"registerVariant\": \"zz new variant \(number)\"," : ""
    let distractors = variant ? "[\"zz n1 \(number)\", \"zz n2 \(number)\"]"
        : "[\"zz n1 \(number)\", \"zz n2 \(number)\", \"zz n3 \(number)\"]"
    return """
    {"id": "zz-exam-i\(number)", "sourcePrompt": "\(prompt ?? "zz new prompt \(number)")", "register": "\(register)",
     "addressee": "any", "canonical": "zz new canonical \(number)",
     "acceptedAnswers": ["zz new canonical \(number)", "zz na \(number)", "zz nb \(number)"], \(variantPart)
     "distractors": \(distractors), "tokens": [{"word": "zz", "english": "zz gloss"}],
     "reviewStatus": "unreviewed"\(levelPart)}
    """
}

private func write(
    items: [String],
    fromLessons: [String],
    language: String = "tamil",
    raw: String? = nil
) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: "zz-exam-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "final.json")
    let lessons = fromLessons.map { "\"\($0)\"" }.joined(separator: ", ")
    let text = raw ?? """
    {"scenarioId": "zz-exam", "language": "\(language)", "title": "zz Exam", "subtitle": "zz sub",
     "items": [\(items.joined(separator: ",\n"))], "fromLessons": [\(lessons)]}
    """
    try text.write(to: file, atomically: true, encoding: .utf8)
    return file
}

struct ExamPaperLoaderTests {
    private let plain = ExamPaperLoader()

    @Test func loadsNewSentencesAndLessonItemsWithTheirLevels() throws {
        let file = try write(
            items: [newItemJSON(1, level: 2), newItemJSON(2, level: 1)],
            fromLessons: ["zz-l1-a-i1", "zz-l2-b-i2"]
        )
        let paper = try plain.load(file: file, catalog: catalog(), language: .tamil).get()
        #expect(paper.total == 4)
        let byID = Dictionary(uniqueKeysWithValues: paper.sources.map { ($0.item.id.rawValue, $0.level) })
        #expect(byID["zz-exam-i1"] == 2)
        #expect(byID["zz-exam-i2"] == 1)
        #expect(byID["zz-l1-a-i1"] == 1)
        #expect(byID["zz-l2-b-i2"] == 2)
    }

    @Test func aLessonItemNotInTheCourseRefusesThePaper() throws {
        let file = try write(items: [newItemJSON(1, level: 1)], fromLessons: ["zz-nope-i1"])
        let result = plain.load(file: file, catalog: catalog(), language: .tamil)
        #expect(result == .failure(ExamPaperLoadFailure(issues: [.unknownLessonItem(ItemID(rawValue: "zz-nope-i1"))])))
    }

    @Test func theSameLessonItemTwiceRefusesThePaper() throws {
        let file = try write(items: [newItemJSON(1, level: 1)], fromLessons: ["zz-l1-a-i1", "zz-l1-a-i1"])
        let result = plain.load(file: file, catalog: catalog(), language: .tamil)
        #expect(result == .failure(ExamPaperLoadFailure(
            issues: [.duplicateLessonItem(ItemID(rawValue: "zz-l1-a-i1"))]
        )))
    }

    @Test func aNewSentenceNeedsALevelFromOneToEight() throws {
        let file = try write(
            items: [newItemJSON(1, level: nil), newItemJSON(2, level: 9), newItemJSON(3, level: 0)],
            fromLessons: []
        )
        guard case .failure(let failure) = plain.load(file: file, catalog: catalog(), language: .tamil) else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure.issues == (1...3).map { .badExamLevel(ItemID(rawValue: "zz-exam-i\($0)")) })
    }

    @Test func aNewSentenceThatRepeatsALessonPromptOrAnswerIsNotNew() throws {
        // Same words, different case and punctuation: the course's own duplicate rule.
        let file = try write(
            items: [newItemJSON(1, level: 1, prompt: "ZZ lesson prompt zz-l1-a-i1!")],
            fromLessons: []
        )
        let result = plain.load(file: file, catalog: catalog(), language: .tamil)
        #expect(result == .failure(ExamPaperLoadFailure(issues: [.repeatsALesson(ItemID(rawValue: "zz-exam-i1"))])))
    }

    @Test func aPaperForTheOtherCourseIsRefused() throws {
        let file = try write(items: [newItemJSON(1, level: 1)], fromLessons: [], language: "telugu")
        guard case .failure(let failure) = plain.load(file: file, catalog: catalog(), language: .tamil) else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure.issues.count == 1)
        if case .invalidItems = failure.issues[0] {} else { Issue.record("expected invalidItems") }
    }

    @Test func aBrokenOrMissingFileIsRefusedNotRepaired() throws {
        let broken = try write(items: [], fromLessons: [], raw: "not json")
        #expect(plain.load(file: broken, catalog: catalog(), language: .tamil)
            == .failure(ExamPaperLoadFailure(issues: [.malformed])))
        let missing = FileManager.default.temporaryDirectory.appending(path: "zz-none-\(UUID().uuidString).json")
        #expect(plain.load(file: missing, catalog: catalog(), language: .tamil)
            == .failure(ExamPaperLoadFailure(issues: [.unreadable])))
    }

    // MARK: Blueprint

    @Test func theSyllabusBlueprintRejectsASmallPaper() throws {
        let file = try write(items: [newItemJSON(1, level: 1)], fromLessons: ["zz-l1-a-i1"])
        let strict = ExamPaperLoader(blueprint: .syllabus)
        guard case .failure(let failure) = strict.load(file: file, catalog: catalog(), language: .tamil) else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure.issues.contains(.blueprint(level: 1, rule: .newSentenceCount)))
        #expect(failure.issues.contains(.blueprint(level: 1, rule: .lessonQuestionCount)))
        #expect(failure.issues.contains(.blueprint(level: nil, rule: .registerChoiceCount)))
    }

    @Test func aPaperThatFollowsTheSyllabusBlueprintLoads() throws {
        let blueprint = ExamBlueprint.syllabus
        let course = catalog(levels: 8, withVariants: true)
        var number = 0
        var items: [String] = []
        var lessons: [String] = []
        for row in blueprint.rows {
            for _ in 0..<row.newSentences {
                number += 1
                items.append(newItemJSON(number, level: row.level, variant: true))
            }
            // Four from lessons per row (three for levels 7 and 8), at most two from each lesson.
            let ids = ["a-i1", "a-i2", "b-i1", "b-i2"].map { "zz-l\(row.level)-\($0)" }
            lessons.append(contentsOf: ids.prefix(row.fromLessons))
        }
        let file = try write(items: items, fromLessons: lessons)
        let paper = try ExamPaperLoader(blueprint: blueprint).load(file: file, catalog: course, language: .tamil).get()
        #expect(paper.total == 100)
    }

    @Test func aLessonUsedThreeTimesBreaksTheBlueprint() throws {
        let blueprint = ExamBlueprint(
            rows: [.init(level: 1, fromLessons: 3, newSentences: 0)],
            minimumRegisterChoices: 0,
            maximumPerLesson: 2
        )
        let scenario = Scenario(
            id: ScenarioID(rawValue: "zz-l1-a"),
            title: "zz",
            subtitle: "zz",
            romanisationNote: nil,
            items: (1...3).map { lessonItem("zz-l1-a-i\($0)", scenario: "zz-l1-a") },
            level: Level(number: 1, title: "zz", position: 1),
            language: .tamil
        )
        let course = Catalog(scenarios: [scenario], issues: [])
        let lessons = ["zz-l1-a-i1", "zz-l1-a-i2", "zz-l1-a-i3"]
        let file = try write(items: [newItemJSON(1, level: 1)], fromLessons: lessons)
        let result = ExamPaperLoader(blueprint: blueprint).load(file: file, catalog: course, language: .tamil)
        guard case .failure(let failure) = result else {
            Issue.record("expected a failure")
            return
        }
        #expect(failure.issues.contains(.blueprint(level: nil, rule: .lessonUsedTooOften)))
    }
}
