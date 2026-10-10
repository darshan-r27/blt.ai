import BLTCore

/// A scenario file exactly as it appears on disk. All fields are optional; see `RawItem`.
/// Keys the schema does not name (for example `registerPolicy`) are ignored.
struct RawScenario: Decodable {
    var scenarioId: String?
    var language: String?
    var title: String?
    var subtitle: String?
    var romanisationNote: String?
    var items: [RawItem]?
    var level: RawLevel?
    /// Header fields that were present but had the wrong JSON type. `romanisationNote` is reported as `.note`.
    var malformed: Set<ContentIssue.Field> = []

    private enum CodingKeys: String, CodingKey {
        case scenarioId, language, title, subtitle, romanisationNote, items, level
    }

    /// Throws when the root is not a JSON object, which the loader reports as `malformedJSON`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scenarioId = container.lenient(String.self, forKey: .scenarioId, field: .scenarioId, malformed: &malformed)
        language = container.lenient(String.self, forKey: .language, field: .language, malformed: &malformed)
        title = container.lenient(String.self, forKey: .title, field: .title, malformed: &malformed)
        subtitle = container.lenient(String.self, forKey: .subtitle, field: .subtitle, malformed: &malformed)
        romanisationNote = container.lenient(
            String.self, forKey: .romanisationNote, field: .note, malformed: &malformed
        )
        do {
            level = try container.decodeIfPresent(RawLevel.self, forKey: .level)
        } catch {
            malformed.insert(.level)
        }
        // A non-array `items` is left nil, which the validator reports as an empty scenario.
        items = try? container.decodeIfPresent([RawItem].self, forKey: .items)
    }
}
