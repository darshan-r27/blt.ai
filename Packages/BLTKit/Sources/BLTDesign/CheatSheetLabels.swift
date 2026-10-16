import Foundation

/// Every visible string and VoiceOver label of the cheat sheet screens, built by pure functions so the
/// wording is unit-tested. Plain, calm English: a locked sheet is a thing to look forward to, never a warning.
public enum CheatSheetLabels {
    /// The button on a finished topic's card.
    public static let cardButtonTitle = "Cheat sheet"

    /// The entry on Home that opens the list of every topic's sheet.
    public static let homeEntryTitle = "Cheat sheets"

    /// The title of the list screen.
    public static let screenTitle = "Cheat sheets"

    /// The line shown for a topic that is not finished yet.
    public static let lockedLine = "Finish this topic to see its cheat sheet"

    /// The label on a word whose phrases are not yet checked by a native reviewer.
    public static let unreviewed = "Unreviewed draft"

    /// VoiceOver label of one word row: "word, meaning". Surrounding spaces are trimmed; if either part is
    /// empty only the other is read.
    public static func row(word: String, meaning: String) -> String {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        return [word, meaning].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// VoiceOver label of a list row for a finished topic: "Topic, cheat sheet".
    public static func listRowUnlocked(topic: String) -> String {
        "\(topic), cheat sheet"
    }

    /// VoiceOver label of a list row for a topic still in progress: "Topic, locked. Finish ...".
    public static func listRowLocked(topic: String) -> String {
        "\(topic), locked. \(lockedLine)"
    }
}
