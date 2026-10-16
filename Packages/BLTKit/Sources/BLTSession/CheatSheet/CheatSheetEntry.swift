/// One word on a cheat sheet: what it means and one example phrase that uses it.
public struct CheatSheetEntry: Sendable, Equatable, Identifiable {
    /// The word lowercased, which is how repeated words are matched. Unique within a sheet.
    public let id: String
    /// The word as the topic first spells it (romanised).
    public let word: String
    /// Every distinct English meaning the topic gives this word, in teaching order, joined with "; ".
    public let meaning: String
    /// The first phrase of the topic that uses the word (romanised only).
    public let example: String
    /// True when any phrase that uses this word is unreviewed (the same rule as the lessons).
    public let isUnreviewed: Bool

    public init(id: String, word: String, meaning: String, example: String, isUnreviewed: Bool) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.example = example
        self.isUnreviewed = isUnreviewed
    }
}
