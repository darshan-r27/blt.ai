import BLTCatalog

/// One question on an exam paper: the item to ask and the level it belongs to.
/// `level` is `nil` for a new-sentence question that does not belong to a single level.
public struct ExamQuestionSource: Sendable, Equatable {
    public let item: Item
    public let level: Int?

    public init(item: Item, level: Int?) {
        self.item = item
        self.level = level
    }
}
