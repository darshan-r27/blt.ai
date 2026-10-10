import BLTCatalog
import BLTCore
import Foundation
import Testing

/// Content lives in `content/<language>/*.json` only (DECISIONS 025, 044). No Swift source may carry shipped content
/// as a string literal or any native-script (Tamil or Telugu) code point. This file is scanned too (it holds no
/// content strings by construction: the comparison data is built at runtime from the JSON).
struct NoContentInCodeTests {
    private let minimumLiteralLength = 5
    private let nativeScriptRanges = CourseLanguage.allCases.map(\.scriptRange)

    private func isNativeScriptScalar(_ scalar: Unicode.Scalar) -> Bool {
        nativeScriptRanges.contains { $0.contains(scalar.value) }
    }

    private struct Violation {
        let file: String
        let line: Int
        let isNativeScript: Bool

        var reason: String { isNativeScript ? "native-script code point" : "shipped content string literal" }
    }

    private var repoRoot: URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    /// Every canonical, registerVariant, acceptedAnswers entry and distractor of 5+ characters.
    private func shippedStrings() throws -> Set<String> {
        // One load per course, so a phrase shared by both courses is not dropped as a duplicate.
        var items: [Item] = []
        for language in CourseLanguage.allCases {
            let files = try ShippedContentFiles.files(for: language)
            let catalog = ContentLoader(limits: .default).load(files: files, expectedLanguage: language)
            items += catalog.scenarios.flatMap(\.items)
        }
        var strings: Set<String> = []
        for item in items {
            var candidates = [item.canonical]
            candidates.append(contentsOf: item.acceptedAnswers)
            candidates.append(contentsOf: item.distractors)
            if let variant = item.registerVariant { candidates.append(variant) }
            strings.formUnion(candidates.filter { $0.count >= minimumLiteralLength })
        }
        return strings
    }

    private func swiftFiles() -> [URL] {
        let roots = [
            "Packages/BLTKit/Sources",
            "Packages/BLTKit/Tests",
            "BLTApp/BLTApp",
            "BLTApp/BLTAppUITests"
        ]
        var found: [URL] = []
        for root in roots {
            let directory = repoRoot.appending(path: root, directoryHint: .isDirectory)
            guard let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in walker where url.isFileURL && url.pathExtension == "swift" {
                found.append(url)
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    /// The text of each double-quoted literal on a line, escapes left as written. Good enough for a scan:
    /// it errs towards matching, and a false positive is visible in the failure message.
    private func literals(in line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inside = false
        var escaped = false
        for character in line {
            if inside {
                if escaped {
                    current.append(character)
                    escaped = false
                } else if character == "\\" {
                    current.append(character)
                    escaped = true
                } else if character == "\"" {
                    result.append(current)
                    current = ""
                    inside = false
                } else {
                    current.append(character)
                }
            } else if character == "\"" {
                inside = true
            }
        }
        return result
    }

    private func scan(_ file: URL, content: Set<String>) throws -> [Violation] {
        guard file.isFileURL else { return [] }
        let text = try String(contentsOf: file, encoding: .utf8)
        let relative = String(file.path.dropFirst(repoRoot.path.count + 1))
        var violations: [Violation] = []
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineText = String(line)
            if lineText.unicodeScalars.contains(where: isNativeScriptScalar) {
                violations.append(Violation(file: relative, line: offset + 1, isNativeScript: true))
            }
            if literals(in: lineText).contains(where: { content.contains($0) }) {
                violations.append(Violation(file: relative, line: offset + 1, isNativeScript: false))
            }
        }
        return violations
    }

    private func report(_ violations: [Violation]) -> Comment {
        let lines = violations.map { "\($0.file):\($0.line): \($0.reason)" }
        return Comment(rawValue: "Content must stay in content/<language>/*.json:\n" + lines.joined(separator: "\n"))
    }

    @Test func scanHasSomethingToCompareAgainstAndScan() throws {
        #expect(try !shippedStrings().isEmpty)
        #expect(!swiftFiles().isEmpty)
    }

    @Test func noSwiftFileContainsAShippedContentLiteral() throws {
        let content = try shippedStrings()
        var violations: [Violation] = []
        for file in swiftFiles() {
            violations.append(contentsOf: try scan(file, content: content).filter { !$0.isNativeScript })
        }
        #expect(violations.isEmpty, report(violations))
    }

    @Test func noSwiftFileContainsNativeScript() throws {
        var violations: [Violation] = []
        for file in swiftFiles() {
            violations.append(contentsOf: try scan(file, content: []))
        }
        #expect(violations.isEmpty, report(violations))
    }
}
