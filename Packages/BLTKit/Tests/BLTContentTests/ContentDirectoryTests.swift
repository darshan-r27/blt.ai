import BLTCore
import Foundation
import Testing

struct ContentDirectoryTests {
    @Test func contentFolderHoldsOnlyCourseFolders() throws {
        let stray = try ShippedContentFiles.strayEntries().map(\.lastPathComponent)
        #expect(stray.isEmpty, Comment(rawValue: "Files directly in content/ are never loaded: \(stray)"))
    }

    @Test func everyCourseFolderHoldsJSONLessonFiles() throws {
        for language in CourseLanguage.allCases {
            for file in try ShippedContentFiles.files(for: language) {
                precondition(file.isFileURL)
                let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
                #expect(object?["items"] is [Any], "\(file.lastPathComponent) has no items list")
            }
        }
    }

    @Test func tamilFolderHoldsAtLeastFiveLessons() throws {
        #expect(try ShippedContentFiles.files(for: .tamil).count >= 5)
    }
}
