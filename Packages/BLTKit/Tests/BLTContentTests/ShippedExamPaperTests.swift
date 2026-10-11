import BLTCatalog
import BLTCore
import BLTSession
import Foundation
import Testing

/// A shipped exam paper (`content/<language>/exam/final.json`, DECISIONS 046) must load against its course's
/// lessons and follow the syllabus blueprint. A course with no paper yet is allowed (papers are written after
/// Level 8 is reviewed); once the file exists, every rule applies to it.
struct ShippedExamPaperTests {
    private func paperFile(for language: CourseLanguage) -> URL {
        ShippedContentFiles.directory(for: language)
            .appending(path: "exam", directoryHint: .isDirectory)
            .appending(path: "final.json", directoryHint: .notDirectory)
    }

    @Test func everyShippedPaperLoadsAndFollowsTheBlueprint() throws {
        for language in CourseLanguage.allCases {
            let file = paperFile(for: language)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            let lessons = ContentLoader().load(
                files: try ShippedContentFiles.files(for: language),
                expectedLanguage: language
            )
            let result = ExamPaperLoader(blueprint: .syllabus).load(file: file, catalog: lessons, language: language)
            switch result {
            case .success(let paper):
                #expect(paper.total == 100, "\(language.rawValue) paper has \(paper.total) questions")
            case .failure(let failure):
                Issue.record("\(language.rawValue) exam paper refused: \(failure.issues)")
            }
        }
    }

    @Test func thePaperFolderIsNeverReadAsLessons() throws {
        // `ShippedContentFiles.files` lists only direct children, so an exam folder cannot leak into lessons.
        for language in CourseLanguage.allCases {
            let names = try ShippedContentFiles.files(for: language).map(\.lastPathComponent)
            #expect(!names.contains("final.json"))
        }
    }
}
