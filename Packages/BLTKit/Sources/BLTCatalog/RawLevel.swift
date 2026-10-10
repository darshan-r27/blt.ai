/// The optional `level` object of a scenario file, decoded as leniently as `RawItem`: a missing key is
/// left `nil` for the validator to report, and a key of the wrong JSON type sets `isMalformed`.
struct RawLevel: Decodable {
    var number: Int?
    var title: String?
    var position: Int?
    var isMalformed = false

    private enum CodingKeys: String, CodingKey { case number, title, position }

    /// Throws when `level` is not a JSON object, which `RawScenario` records as a malformed `.level`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var wrongType: Set<ContentIssue.Field> = []
        number = container.lenient(Int.self, forKey: .number, field: .level, malformed: &wrongType)
        title = container.lenient(String.self, forKey: .title, field: .level, malformed: &wrongType)
        position = container.lenient(Int.self, forKey: .position, field: .level, malformed: &wrongType)
        isMalformed = !wrongType.isEmpty
    }
}
