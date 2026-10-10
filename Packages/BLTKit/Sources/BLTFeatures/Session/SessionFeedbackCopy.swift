import BLTCatalog
import BLTCore

/// All feedback wording in one place so it is easy to edit. Plain strings only; nothing here is
/// lesson content (the item data carries that).
struct SessionFeedbackCopy: Equatable {
    let headline: String
    let detail: String

    init(verdict: Verdict, item: Item, willReturn: Bool) {
        switch verdict {
        case .correct:
            headline = "Correct"
            detail = "That is how it is said."
        case .wrongRegister:
            headline = "Right sentence, wrong register for this person"
            detail = Self.registerDetail(for: item.register)
        case .notQuite:
            headline = "Not quite"
            detail = willReturn
                ? "The correct answer is shown below. This one will come back shortly."
                : "The correct answer is shown below. It will be back in a later session."
        }
    }

    /// Says which form to use with whom. `wrongRegister` only happens for an item that has a
    /// register variant, so `.neutral` should be unreachable; it still gets honest generic text
    /// rather than a crash.
    private static func registerDetail(for itemRegister: Register) -> String {
        switch itemRegister {
        case .respectful:
            "What you chose is the casual form. It is fine with a friend. "
                + "For an elder or someone you have just met, use the respectful form shown below."
        case .casual:
            "What you chose is the respectful form. It suits an elder or someone you have just met. "
                + "For a friend, use the casual form shown below."
        case .neutral:
            "What you chose suits a different person. The form to use here is shown below."
        }
    }

    static let canonicalLabel = "Say it like this"
    static let chosenLabel = "You chose"
    static let continueTitle = "Continue"
}
