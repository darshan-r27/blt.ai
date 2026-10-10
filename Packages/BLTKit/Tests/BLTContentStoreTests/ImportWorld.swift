import BLTCatalog
import BLTCore
@testable import BLTContentStore
import Foundation
import Testing

/// Shared fixtures for the import tests.

/// A throwaway world for one test: a "bundled" folder, an import folder and a folder the learner
/// "picks" files from. All text is obviously fake (`zz`).
struct ImportWorld {
    let root: URL
    let bundled: URL
    let imported: URL
    let picked: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "zz-blt-import-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        bundled = root.appending(path: "bundled", directoryHint: .isDirectory)
        imported = root.appending(path: "imported", directoryHint: .isDirectory)
        picked = root.appending(path: "picked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func store(language: CourseLanguage? = .tamil, loader: ContentLoader = ContentLoader()) -> ImportedContentStore {
        ImportedContentStore(directory: imported, bundledDirectory: bundled, language: language, loader: loader)
    }

    @discardableResult
    func writeBundled(_ name: String, _ text: String) throws -> URL {
        let url = bundled.appending(path: name, directoryHint: .notDirectory)
        try Data(text.utf8).write(to: url)
        return url
    }

    @discardableResult
    func writeBundledScenario(
        _ id: String,
        title: String = "zz title",
        language: CourseLanguage = .tamil,
        items: [String]
    ) throws -> URL {
        try writeBundled("\(id).json", Self.scenarioJSON(id, title: title, language: language, items: items))
    }

    func pick(_ name: String, _ text: String) throws -> URL {
        let url = picked.appending(path: name, directoryHint: .notDirectory)
        try Data(text.utf8).write(to: url)
        return url
    }

    /// Picks a valid one-item-per-id scenario file named after its id.
    func pickScenario(
        _ id: String,
        title: String = "zz title",
        language: CourseLanguage = .tamil,
        items: [String]
    ) throws -> URL {
        try pick("\(id)-picked.json", Self.scenarioJSON(id, title: title, language: language, items: items))
    }

    func layered(language: CourseLanguage = .tamil) -> ContentBootstrapResult {
        BundleContentLoader().load(directory: bundled, language: language, importedDirectory: imported)
    }

    func importedFileNames() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: imported.path())) ?? []
        return names.sorted()
    }

    static func scenarioJSON(
        _ scenarioID: String,
        title: String = "zz title",
        language: CourseLanguage = .tamil,
        items: [String]
    ) -> String {
        scenarioJSON(scenarioID, title: title, language: language, rawItems: items.map { itemJSON(id: $0) })
    }

    static func scenarioJSON(
        _ scenarioID: String,
        title: String = "zz title",
        language: CourseLanguage = .tamil,
        rawItems: [String]
    ) -> String {
        let body = rawItems.joined(separator: ",")
        return """
        {"scenarioId": "\(scenarioID)", "language": "\(language.rawValue)", "title": "\(title)",
         "subtitle": "zz subtitle", "items": [\(body)]}
        """
    }

    static func itemJSON(
        id: String,
        sourcePrompt: String? = nil,
        accepted: String? = nil,
        distractors: String = #"["zz wrong a", "zz wrong b"]"#
    ) -> String {
        let accepted = accepted ?? #"["zz canonical \#(id)", "zz canonical b \#(id)", "zz canonical c \#(id)"]"#
        return """
        {"id": "\(id)", "sourcePrompt": "\(sourcePrompt ?? "zz prompt \(id)")", "register": "respectful",
         "addressee": "any", "canonical": "zz canonical \(id)", "acceptedAnswers": \(accepted),
         "registerVariant": "zz casual",
         "distractors": \(distractors), "tokens": [{"word": "zz", "english": "zz gloss"}],
         "note": null, "reviewStatus": "unreviewed"}
        """
    }
}

func attempt(
    _ store: ImportedContentStore,
    _ urls: [URL]
) -> Result<ImportedContentSummary, ContentImportFailure> {
    do {
        return .success(try store.importFiles(urls))
    } catch {
        return .failure(error)
    }
}

func isInvalid(_ result: Result<ImportedContentSummary, ContentImportFailure>) -> Bool {
    if case .failure(.invalid) = result { return true }
    return false
}
