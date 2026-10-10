import Foundation
import BLTCore
import Testing

struct CourseLanguageTests {
    @Test func rawValuesMatchTheLessonFileSchema() {
        #expect(CourseLanguage.allCases.map(\.rawValue) == ["tamil", "telugu"])
    }

    @Test func decodesFromAndEncodesToTheRawValue() throws {
        let decoded = try JSONDecoder().decode([CourseLanguage].self, from: Data(#"["tamil","telugu"]"#.utf8))
        #expect(decoded == [.tamil, .telugu])
        let encoded = try JSONEncoder().encode(CourseLanguage.telugu)
        #expect(String(bytes: encoded, encoding: .utf8) == #""telugu""#)
    }

    @Test func unknownLanguageDoesNotDecode() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CourseLanguage.self, from: Data(#""zz""#.utf8))
        }
    }

    @Test func namesAndPrefixesAreDistinct() {
        #expect(Set(CourseLanguage.allCases.map(\.displayName)).count == 2)
        #expect(Set(CourseLanguage.allCases.map(\.idPrefix)).count == 2)
        #expect(CourseLanguage.tamil.idPrefix == "ta")
        #expect(CourseLanguage.telugu.idPrefix == "te")
    }

    @Test func scriptRangesAreTheTwoUnicodeBlocksAndDoNotOverlap() {
        #expect(CourseLanguage.tamil.scriptRange == 0x0B80...0x0BFF)
        #expect(CourseLanguage.telugu.scriptRange == 0x0C00...0x0C7F)
        #expect(!CourseLanguage.tamil.scriptRange.overlaps(CourseLanguage.telugu.scriptRange))
    }

    @Test func scriptMembershipUsesNumericScalarsOnly() throws {
        let tamilLetter = try #require(Unicode.Scalar(0x0B85))
        let teluguLetter = try #require(Unicode.Scalar(0x0C05))
        let latin = try #require(Unicode.Scalar(0x007A))
        #expect(CourseLanguage.tamil.isScriptScalar(tamilLetter))
        #expect(!CourseLanguage.tamil.isScriptScalar(teluguLetter))
        #expect(CourseLanguage.telugu.isScriptScalar(teluguLetter))
        #expect(!CourseLanguage.telugu.isScriptScalar(latin))
    }
}
