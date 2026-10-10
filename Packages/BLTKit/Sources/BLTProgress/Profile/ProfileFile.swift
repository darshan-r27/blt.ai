import BLTCore
import Foundation

/// The on-disk envelope: `{"schemaVersion": 2, "name": "...", "learningLanguage": "..."}`.
///
/// Internal; callers only ever see `UserProfile`. The name is stored exactly as given: validation is the
/// caller's job (`ProfileNameValidator`), so the store never changes what the user typed.
///
/// Schema 2 (DECISIONS 043) adds `learningLanguage`, which is omitted while the learner has not chosen
/// one. Schema 1 files, written before the language existed, still load and have no language. Writing
/// always uses schema 2.
struct ProfileFile: Codable, Equatable {
    static let currentSchemaVersion = 2

    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    /// The schema 1 shape: a name and nothing else. Any other key in a schema 1 file is ignored.
    private struct LegacyFile: Decodable {
        let name: String
    }

    let schemaVersion: Int
    let name: String
    /// An unknown or non-string value fails decoding, so the file is reported as corrupt rather than
    /// quietly loaded without a language.
    let learningLanguage: CourseLanguage?

    init(profile: UserProfile) {
        schemaVersion = Self.currentSchemaVersion
        name = profile.name
        learningLanguage = profile.learningLanguage
    }

    /// Maps raw file bytes to a profile. Every failure becomes a `ProfileStoreError`; nothing in the
    /// error carries file content.
    static func decodeProfile(from data: Data) throws(ProfileStoreError) -> UserProfile {
        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            switch header.schemaVersion {
            case 1:
                return UserProfile(name: try decoder.decode(LegacyFile.self, from: data).name)
            case currentSchemaVersion:
                let file = try decoder.decode(ProfileFile.self, from: data)
                return UserProfile(name: file.name, learningLanguage: file.learningLanguage)
            default:
                throw ProfileStoreError.unsupportedSchemaVersion(header.schemaVersion)
            }
        } catch let error as ProfileStoreError {
            throw error
        } catch {
            throw .corrupt
        }
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
