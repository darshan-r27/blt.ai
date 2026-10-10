import BLTCatalog
import Foundation

/// Builders shared by the catalog-format tests. Everything is obviously fake ("zz"); the Tamil-script fixture
/// is one letter repeated, written as an escape, never a real word.
enum CatalogFormatFixtures {
    typealias JSONObject = [String: Any]

    /// One Tamil letter repeated: obviously not a real word.
    static let fakeTamil = "\u{0B85}\u{0B85}\u{0B85}"

    static func item(
        id: String,
        prompt: String? = nil,
        canonical: String? = nil,
        accepted: [String]? = nil
    ) -> JSONObject {
        let canonical = canonical ?? "zz canonical \(id)"
        return [
            "id": id,
            "sourcePrompt": prompt ?? "zz prompt \(id)",
            "register": "respectful",
            "addressee": "any",
            "canonical": canonical,
            "acceptedAnswers": accepted ?? [canonical, "zz b \(id)", "zz c \(id)"],
            "registerVariant": "zz casual \(id)",
            "distractors": ["zz wrong a", "zz wrong b"],
            "tokens": [["tamil": "zz", "english": "zz gloss"]],
            "note": NSNull(),
            "reviewStatus": "unreviewed"
        ]
    }

    static func scenario(
        id: String = "zz-scenario",
        level: JSONObject? = nil,
        items: [JSONObject]
    ) -> JSONObject {
        var raw: JSONObject = ["scenarioId": id, "title": "zz title", "subtitle": "zz subtitle", "items": items]
        if let level { raw["level"] = level }
        return raw
    }

    static func level(number: Int = 1, title: String = "zz level", position: Int = 1) -> JSONObject {
        ["number": number, "title": title, "position": position]
    }

    static func load(_ scenarios: [JSONObject]) throws -> Catalog {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "zz-blt-format-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = try scenarios.enumerated().map { index, object in
            let url = directory.appending(path: "scenario-\(index).json", directoryHint: .notDirectory)
            try JSONSerialization.data(withJSONObject: object).write(to: url)
            return url
        }
        return ContentLoader().load(files: urls)
    }
}
