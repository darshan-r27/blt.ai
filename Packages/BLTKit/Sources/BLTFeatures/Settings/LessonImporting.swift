import Foundation

/// What Settings needs to import lesson files, so the view model can be tested with a fake.
/// The real implementation is `ImportedContentStore`.
public protocol LessonImporting: Sendable {
    /// Validates and stores the chosen files, all or nothing.
    func importFiles(_ urls: [URL]) async throws(ContentImportFailure) -> ImportedContentSummary
    /// Deletes every imported lesson file.
    func removeAll() async throws(ContentImportFailure)
    /// The imports that are active right now.
    func currentSummary() async -> ImportedContentSummary
}

/// The store does blocking file I/O, so each call runs on a detached task rather than the main actor.
extension ImportedContentStore: LessonImporting {
    public func importFiles(_ urls: [URL]) async throws(ContentImportFailure) -> ImportedContentSummary {
        let store = self
        let result = await Task.detached { Result { () throws(ContentImportFailure) in try store.importFiles(urls) } }
            .value
        return try result.get()
    }

    public func removeAll() async throws(ContentImportFailure) {
        let store = self
        let result = await Task.detached { Result { () throws(ContentImportFailure) in try store.removeAll() } }
            .value
        try result.get()
    }

    public func currentSummary() async -> ImportedContentSummary {
        let store = self
        return await Task.detached { store.currentSummary() }.value
    }
}
