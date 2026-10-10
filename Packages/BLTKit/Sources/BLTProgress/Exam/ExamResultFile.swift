import Foundation

/// The on-disk envelope: `{"schemaVersion": 1, "attempts": [...]}`, oldest attempt first.
///
/// Internal; callers only ever see `[ExamAttempt]`.
struct ExamResultFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    let schemaVersion: Int
    let attempts: [ExamAttempt]

    init(attempts: [ExamAttempt]) {
        schemaVersion = Self.currentSchemaVersion
        self.attempts = attempts
    }

    /// Maps raw file bytes to attempts. Every failure becomes an `ExamResultStoreError`; nothing in the
    /// error carries file content.
    static func decodeAttempts(from data: Data) throws(ExamResultStoreError) -> [ExamAttempt] {
        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == currentSchemaVersion else {
                throw ExamResultStoreError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return try decoder.decode(ExamResultFile.self, from: data).attempts
        } catch let error as ExamResultStoreError {
            throw error
        } catch {
            throw .corrupt
        }
    }

    func encoded() throws(ExamResultStoreError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .writeFailed
        }
    }
}
