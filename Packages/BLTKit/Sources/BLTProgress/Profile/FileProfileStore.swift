import Foundation

/// Stores the profile as one JSON file (DECISIONS 030). See `ProfileFile` for the format.
///
/// Mirrors `FileProgressStore`: a file that cannot be decoded, or that comes from a newer schema, is never
/// overwritten or deleted by `load` or `save`; only an explicit `erase` removes it. Errors carry no paths
/// and no file content.
///
/// `save` stores exactly the string it is given. It does not validate: callers run the name through
/// `ProfileNameValidator` first, so the store never silently changes what the user typed.
///
/// Data protection (`.completeFileProtection`) is requested on every write but is not enforced in the
/// Simulator, so it is only verifiable on a device.
public actor FileProfileStore: ProfileStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        precondition(fileURL.isFileURL, "profile file must be a file URL")
        self.fileURL = fileURL
    }

    public func load() async throws(ProfileStoreError) -> UserProfile? {
        try readProfile()
    }

    public func save(_ profile: UserProfile) async throws(ProfileStoreError) {
        // Reading first means a corrupt or future-schema file throws here instead of being replaced.
        _ = try readProfile()
        let data = try ProfileFile(profile: profile).encoded()
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

    public func erase() async throws(ProfileStoreError) {
        // unlink(2) rather than FileManager.removeItem: it removes a file and nothing else, so a
        // misconfigured URL that names a directory fails instead of deleting a tree.
        let result = fileURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return EINVAL }
            return unlink(path) == 0 ? 0 : errno
        }
        guard result == 0 || result == ENOENT else { throw .eraseFailed }
    }

    private func readProfile() throws(ProfileStoreError) -> UserProfile? {
        guard fileURL.isFileURL else { throw .unreadable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        } catch {
            throw .unreadable
        }
        return try ProfileFile.decodeProfile(from: data)
    }
}
