/// Why a typed name was rejected by `ProfileNameValidator`.
public enum ProfileNameError: Error, Sendable, Equatable {
    /// Nothing is left once surrounding whitespace is removed.
    case empty
    /// More than 40 characters once whitespace is normalised.
    case tooLong
    /// Contains a control character, including a newline or tab inside the name.
    case invalidCharacters
}
