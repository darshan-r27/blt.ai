import BLTCore

/// An item exactly as it appears in a content file. Every field is optional so that a missing field
/// becomes a `ContentIssue` in the validator rather than a decoding crash. Unknown keys are ignored.
///
/// A present field of the wrong JSON type is recorded in `malformed` instead of failing the whole file,
/// so one bad item cannot take its valid siblings down with it.
struct RawItem: Decodable {
    /// A `{word, english}` gloss entry, decoded with the same leniency as its parent.
    struct TokenEntry: Decodable {
        var word: String?
        var english: String?
        var isMalformed = false

        init(from decoder: any Decoder) throws {
            guard let container = try? decoder.container(keyedBy: TokenKeys.self) else {
                isMalformed = true
                return
            }
            var wrongType: Set<ContentIssue.Field> = []
            word = container.lenient(String.self, forKey: .word, field: .tokens, malformed: &wrongType)
            english = container.lenient(String.self, forKey: .english, field: .tokens, malformed: &wrongType)
            isMalformed = !wrongType.isEmpty
        }
    }

    /// Keys of a gloss entry; declared here because types may nest only one level deep.
    private enum TokenKeys: String, CodingKey { case word, english }

    var id: String?
    var sourcePrompt: String?
    var register: String?
    var addressee: String?
    var canonical: String?
    var acceptedAnswers: [String]?
    var registerVariant: String?
    var distractors: [String]?
    var tokens: [TokenEntry]?
    var note: String?
    var reviewStatus: String?
    var script: String?
    /// Fields that were present but had the wrong JSON type.
    var malformed: Set<ContentIssue.Field> = []
    /// The array element was not a JSON object at all.
    var isNotAnObject = false

    private enum CodingKeys: String, CodingKey {
        case id, sourcePrompt, register, addressee, canonical, acceptedAnswers
        case registerVariant, distractors, tokens, note, reviewStatus, script
    }

    init(from decoder: any Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            isNotAnObject = true
            return
        }
        id = container.lenient(String.self, forKey: .id, field: .id, malformed: &malformed)
        sourcePrompt = container.lenient(
            String.self, forKey: .sourcePrompt, field: .sourcePrompt, malformed: &malformed
        )
        register = container.lenient(String.self, forKey: .register, field: .register, malformed: &malformed)
        addressee = container.lenient(String.self, forKey: .addressee, field: .addressee, malformed: &malformed)
        canonical = container.lenient(String.self, forKey: .canonical, field: .canonical, malformed: &malformed)
        acceptedAnswers = container.lenient(
            [String].self, forKey: .acceptedAnswers, field: .acceptedAnswers, malformed: &malformed
        )
        registerVariant = container.lenient(
            String.self, forKey: .registerVariant, field: .registerVariant, malformed: &malformed
        )
        distractors = container.lenient(
            [String].self, forKey: .distractors, field: .distractors, malformed: &malformed
        )
        tokens = container.lenient([TokenEntry].self, forKey: .tokens, field: .tokens, malformed: &malformed)
        note = container.lenient(String.self, forKey: .note, field: .note, malformed: &malformed)
        reviewStatus = container.lenient(
            String.self, forKey: .reviewStatus, field: .reviewStatus, malformed: &malformed
        )
        script = container.lenient(
            String.self, forKey: .script, field: .script, malformed: &malformed
        )
    }
}

extension KeyedDecodingContainer {
    /// Decodes `key` if it is present and not `null`. A value of the wrong type is recorded in `malformed`
    /// (the validator reports it) rather than thrown, so the caller never silently substitutes a default.
    func lenient<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key,
        field: ContentIssue.Field,
        malformed: inout Set<ContentIssue.Field>
    ) -> Value? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            malformed.insert(field)
            return nil
        }
    }
}
