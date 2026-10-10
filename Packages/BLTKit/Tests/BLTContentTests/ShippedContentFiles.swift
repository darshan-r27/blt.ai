import BLTCore
import Foundation

/// Where the shipped lessons live: one folder per course, `content/<language>/*.json` (DECISIONS 044).
/// Every content test reads through this type, so nothing reads a flat `content/*.json`.
enum ShippedContentFiles {
    /// Repo root, found from this file's path: Packages/BLTKit/Tests/BLTContentTests/<file>.
    static var repoRoot: URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    static var contentDirectory: URL {
        repoRoot.appending(path: "content", directoryHint: .isDirectory)
    }

    /// The folder for one course. It is named by the language's raw value, the same text a lesson writes in `language`.
    static func directory(for language: CourseLanguage) -> URL {
        contentDirectory.appending(path: language.rawValue, directoryHint: .isDirectory)
    }

    /// The lesson files of one course, sorted by name. A folder that does not exist yet (Telugu, before its
    /// first lesson is written) is a course with no lessons, not an error.
    static func files(for language: CourseLanguage) throws -> [URL] {
        let folder = directory(for: language)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.isFileURL && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Anything sitting directly in `content/` instead of in a course folder.
    static func strayEntries() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: contentDirectory, includingPropertiesForKeys: nil)
            .filter { entry in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory)
                return !isDirectory.boolValue
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
