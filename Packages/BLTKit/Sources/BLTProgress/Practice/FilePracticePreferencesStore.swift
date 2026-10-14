import Foundation

/// Stores the preferences as one small JSON file, for example
/// `{"hasAskedForNotifications":false,"quietHours":{"endMinute":480,"startMinute":1320},"remindersEnabled":true,"schemaVersion":1}`.
///
/// Mirrors `FilePracticeLogStore`: writes are atomic, and a file that cannot be decoded (or comes from a
/// newer schema) is reported and never overwritten, not even by `save`. Errors carry no paths and no file
/// content. The app chooses the URL.
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FilePracticePreferencesStore: PracticePreferencesStore {
    /// Decoded first, on its own, so a file from a future schema is reported as such even when the rest
    /// of its shape no longer matches this version's.
    private struct Header: Decodable {
        let schemaVersion: Int
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "practice preferences file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(PracticePreferencesError) -> PracticePreferences {
        try readPreferences() ?? .standard
    }

    public func save(_ preferences: PracticePreferences) async throws(PracticePreferencesError) {
        // Reading first means a corrupt or future-schema file throws here instead of being replaced.
        _ = try readPreferences()
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(preferences)
        } catch {
            throw .writeFailed
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw .writeFailed
        }
    }

    /// `nil` when there is no file yet.
    private func readPreferences() throws(PracticePreferencesError) -> PracticePreferences? {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        } catch {
            throw .unreadable
        }
        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.schemaVersion == PracticePreferences.currentSchemaVersion else {
                throw PracticePreferencesError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return try decoder.decode(PracticePreferences.self, from: data)
        } catch let error as PracticePreferencesError {
            throw error
        } catch {
            throw .corrupt
        }
    }
}
