import BLTCatalog
import BLTCore

public struct Question: Sendable, Equatable, Identifiable {
    public let item: Item
    /// Exactly four options, already shuffled.
    public let options: [AnswerOption]

    public init(item: Item, options: [AnswerOption]) {
        self.item = item
        self.options = options
    }

    public var id: ItemID { item.id }

    /// `nil` when `optionID` is not one of this question's options.
    public func verdict(for optionID: AnswerOption.ID) -> Verdict? {
        guard let option = options.first(where: { $0.id == optionID }) else { return nil }
        switch option.kind {
        case .canonical: return .correct
        case .registerVariant: return .wrongRegister(correct: item.canonical)
        case .distractor: return .notQuite(correct: item.canonical)
        }
    }
}
