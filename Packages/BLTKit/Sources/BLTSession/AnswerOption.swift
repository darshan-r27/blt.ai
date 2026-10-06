public struct AnswerOption: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case canonical
        case registerVariant
        case distractor
    }

    /// 0 canonical, 1 register variant (if any), then distractors. Display order is the array order.
    public let id: Int
    public let text: String
    public let kind: Kind

    public init(id: Int, text: String, kind: Kind) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}
