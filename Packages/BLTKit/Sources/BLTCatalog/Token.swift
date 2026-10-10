/// One gloss entry: a word as it appears in the item's `canonical` answer, and what it means.
public struct Token: Sendable, Equatable {
    public let word: String
    public let english: String

    public init(word: String, english: String) {
        self.word = word
        self.english = english
    }
}
