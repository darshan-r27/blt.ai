import Foundation

/// The on-disk envelope: `{"schemaVersion": 1, "name": "..."}`.
///
/// Internal; callers only ever see `UserProfile`. The name is stored exactly as given: validation is the
/// caller's job (`ProfileNameValidator`), so the store never changes what the user typed.
struct ProfileFile: Codable, Equatable {
    static let currentSchemaVersion = 1

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    let schemaVersion: Int
    let name: String

    init(profile: UserProfile) {
        schemaVersion = Self.currentSchemaVersion
        name = profile.name
    }

    /// Maps raw file bytes to a profile. Every failure becomes a `ProfileStoreError`; nothing in the
    /// error carries file content.
    static func decodeProfile(from data: Data) throws(ProfileStoreError) -> UserProfile {
        let decoder = JSONDecoder()
        let file: ProfileFile
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == currentSchemaVersion else {
                throw ProfileStoreError.unsupportedSchemaVersion(header.schemaVersion)
            }
            file = try decoder.decode(ProfileFile.self, from: data)
        } catch let error as ProfileStoreError {
            throw error
        } catch {
            throw .corrupt
        }
        return UserProfile(name: file.name)
    }

    func encoded() throws(ProfileStoreError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .writeFailed
        }
    }
}
