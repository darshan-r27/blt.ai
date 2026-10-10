/// The language a learner is studying. The raw value is what lesson files write in `language`.
public enum CourseLanguage: String, Sendable, Codable, CaseIterable {
    case tamil
    case telugu

    /// The language's English name, for screens that name the course.
    public var displayName: String {
        switch self {
        case .tamil: "Tamil"
        case .telugu: "Telugu"
        }
    }

    /// Prefix of the lesson and item ids in this course (`ta-l02-u03`).
    public var idPrefix: String {
        switch self {
        case .tamil: "ta"
        case .telugu: "te"
        }
    }

    /// The Unicode block of the language's own script. Content keeps native script in the `script` field only.
    public var scriptRange: ClosedRange<UInt32> {
        switch self {
        case .tamil: 0x0B80...0x0BFF
        case .telugu: 0x0C00...0x0C7F
        }
    }

    /// Whether `scalar` belongs to this language's script block.
    public func isScriptScalar(_ scalar: Unicode.Scalar) -> Bool {
        scriptRange.contains(scalar.value)
    }
}
