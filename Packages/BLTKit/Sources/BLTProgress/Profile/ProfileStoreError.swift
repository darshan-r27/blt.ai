public enum ProfileStoreError: Error, Sendable, Equatable {
    case unreadable
    /// The file exists but cannot be decoded. It must never be silently overwritten.
    case corrupt
    case unsupportedSchemaVersion(Int)
    case writeFailed
    case eraseFailed
}
