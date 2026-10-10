/// One gloss entry: a word as it appears in the item's `canonical` answer, and what it means.
public struct Token: Sendable, Equatable {
    public let word: String
    public let english: String

    public init(word: String, english: String) {
        self.word = word
        self.english = english
    }

    /// Old name of `word`, kept so callers outside `BLTCatalog` still compile.
    /// Removed when Wave 3 updates its callers.
    public var tamil: String { word }

    /// Old initializer label, kept for the same reason. Removed when Wave 3 updates its callers.
    public init(tamil: String, english: String) {
        self.init(word: tamil, english: english)
    }
}
