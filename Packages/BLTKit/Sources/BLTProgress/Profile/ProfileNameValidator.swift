/// Normalises and checks a display name typed by the user (DECISIONS 030).
///
/// Steps, in order:
/// 1. Trim leading and trailing whitespace and newlines.
/// 2. Reject any control character left inside the name (a newline or tab in the middle is not a name).
/// 3. Collapse each run of inner whitespace (spaces, no-break spaces and the like) to one space.
/// 4. Require 1 to 40 `Character`s.
///
/// Letters, marks, digits, spaces, hyphens, apostrophes and periods in any script are accepted because
/// the name is the user's own. Format characters such as the zero-width joiner are deliberately not
/// rejected: several Indic scripts need them to spell ordinary names.
public enum ProfileNameValidator {
    public static let maximumLength = 40

    public static func validate(_ raw: String) -> Result<String, ProfileNameError> {
        let trimmed = trimmingWhitespace(raw)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard !trimmed.unicodeScalars.contains(where: isRejected) else { return .failure(.invalidCharacters) }

        let collapsed = trimmed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count <= maximumLength else { return .failure(.tooLong) }
        return .success(collapsed)
    }

    private static func trimmingWhitespace(_ text: String) -> String {
        guard let start = text.firstIndex(where: { !$0.isWhitespace }),
              let end = text.lastIndex(where: { !$0.isWhitespace }) else { return "" }
        return String(text[start...end])
    }

    /// Control characters, plus the Unicode line and paragraph separators, which break lines like a newline.
    private static func isRejected(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator: true
        default: false
        }
    }
}
