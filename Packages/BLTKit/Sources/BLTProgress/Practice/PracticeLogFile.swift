import Foundation

/// The on-disk envelope: `{"schemaVersion": 1, "sessions": [{"answered": 10, "finishedAt": 1760000000}]}`.
///
/// Dates are numeric seconds since 1970 so they round-trip exactly (see `ProgressFile`). Sessions are
/// written oldest first. Internal; callers only ever see `PracticeLog`.
struct PracticeLogFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    let schemaVersion: Int
    let sessions: [PracticeSession]

    init(log: PracticeLog) {
        schemaVersion = Self.currentSchemaVersion
        sessions = log.sessions
    }

    /// Maps raw file bytes to a log. Every failure becomes a `PracticeLogError`; nothing in the error
    /// carries file content.
    static func decodeLog(from data: Data) throws(PracticeLogError) -> PracticeLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == currentSchemaVersion else {
                throw PracticeLogError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return PracticeLog(sessions: try decoder.decode(PracticeLogFile.self, from: data).sessions)
        } catch let error as PracticeLogError {
            throw error
        } catch {
            throw .corrupt
        }
    }

    func encoded() throws(PracticeLogError) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .writeFailed
        }
    }
}
