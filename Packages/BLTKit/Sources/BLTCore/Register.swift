public enum Register: String, Sendable, Codable, CaseIterable {
    case casual
    case respectful
    /// The sentence has no you-form, so there is no register choice.
    case neutral
}
