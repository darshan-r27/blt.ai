import Foundation

/// The on-disk envelope: `{"schemaVersion": 1, "topicIDs": ["zz-topic-a", "zz-topic-b"]}`.
///
/// Topic ids are written sorted so the file is stable. Internal; callers only ever see `Set<String>`.
struct CheatSheetUnlockFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    let schemaVersion: Int
    let topicIDs: [String]

    init(topicIDs: Set<String>) {
        schemaVersion = Self.currentSchemaVersion
        self.topicIDs = topicIDs.sorted()
    }

    /// Maps raw file bytes to the unlocked set. Every failure becomes a `CheatSheetUnlockError`; nothing in
    /// the error carries file content.
    static func decodeTopicIDs(from data: Data) throws(CheatSheetUnlockError) -> Set<String> {
        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == currentSchemaVersion else {
                throw CheatSheetUnlockError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return Set(try decoder.decode(CheatSheetUnlockFile.self, from: data).topicIDs)
        } catch let error as CheatSheetUnlockError {
            throw error
        } catch {
            throw .corrupt
        }
    }

    func encoded() throws(CheatSheetUnlockError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .writeFailed
        }
    }
}
