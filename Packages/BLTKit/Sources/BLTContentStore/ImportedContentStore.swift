import BLTCatalog
import BLTCore
import Foundation

/// The scenarios an import has made active, for the Settings text.
public struct ImportedContentSummary: Sendable, Equatable {
    /// Sorted by raw value.
    public let scenarioIDs: [ScenarioID]

    public var count: Int { scenarioIDs.count }

    public init(scenarioIDs: [ScenarioID]) {
        self.scenarioIDs = scenarioIDs.sorted { $0.rawValue < $1.rawValue }
    }
}

/// Why an import did not happen. Closed, with no free text and no paths, so it is safe to log.
public enum ContentImportFailure: Error, Sendable, Equatable {
    case noFiles
    case tooManyFiles(limit: Int)
    /// A chosen file could not be read (for example an iCloud file that is not downloaded).
    case unreadable
    /// At least one chosen file broke a content rule, or would break the lessons already in the app.
    case invalid(issueCount: Int)
    case couldNotSave
}

/// Lesson files the learner imported into one course, kept in `directory` and layered over that
/// course's bundled content by `BundleContentLoader`.
///
/// A store is built for one course. A file written for the other course fails the whole import with
/// `invalid` (the validator reports `wrongLanguage`) and nothing changes.
///
/// Imported files are untrusted input: they go through the same `ContentLoader` validator as the
/// bundled files, the whole batch is rejected if any file has any issue, and the stored file name is
/// a hash of the scenario id, never the learner's file name or the id's own characters.
public struct ImportedContentStore: Sendable {
    public static let maxFilesPerImport = 20

    /// Hard ceiling on what is read into memory, whatever limits the loader was given.
    private static let readCeiling = ContentLoader.Limits.default.maxFileBytes
    private static let stagingPrefix = "staging-"

    private let directory: URL
    private let bundledDirectory: URL?
    private let language: CourseLanguage
    private let loader: ContentLoader

    /// `directory` is created on the first write. `bundledDirectory` is the course's bundled folder
    /// (`content/<language>`; `nil` if missing, in which case nothing is replaced).
    ///
    /// `language` is the course the store imports into. It is required: a store that accepted either course
    /// could put a lesson in the wrong one.
    public init(
        directory: URL,
        bundledDirectory: URL?,
        language: CourseLanguage,
        loader: ContentLoader = ContentLoader()
    ) {
        self.directory = directory
        self.bundledDirectory = bundledDirectory
        self.language = language
        self.loader = loader
    }

    /// Validates and stores the chosen files, all or nothing. Blocking file I/O: call it off the
    /// main actor. On success the imports are active the next time the catalog is loaded.
    public func importFiles(_ urls: [URL]) throws(ContentImportFailure) -> ImportedContentSummary {
        guard !urls.isEmpty else { throw .noFiles }
        guard urls.count <= Self.maxFilesPerImport else { throw .tooManyFiles(limit: Self.maxFilesPerImport) }
        let nonFileCount = urls.filter { !$0.isFileURL }.count
        guard nonFileCount == 0 else { throw .invalid(issueCount: nonFileCount) }

        // Security-scoped access must stay open while the bytes are read; it is released on every exit.
        var accessed: [URL] = []
        defer { for url in accessed { url.stopAccessingSecurityScopedResource() } }
        var sources: [Data] = []
        for url in urls {
            if url.startAccessingSecurityScopedResource() { accessed.append(url) }
            sources.append(try Self.readSource(at: url))
        }

        let staging = try makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: staging) }
        let staged = try stage(sources, in: staging)

        let importedIDs = try validate(staged)
        try persist(sources, scenarioIDs: importedIDs)
        return currentSummary()
    }

    /// Deletes every imported file and the manifest. Missing files are not an error.
    public func removeAll() throws(ContentImportFailure) {
        let manifest = ImportedContentManifest.read(from: directory)
        do {
            try Self.removeIfPresent(ImportedContentManifest.url(in: directory))
            for entry in manifest.entries {
                try Self.removeIfPresent(directory.appending(path: entry.fileName, directoryHint: .notDirectory))
            }
        } catch {
            throw .couldNotSave
        }
    }

    /// The imports that are active against the current bundled content.
    public func currentSummary() -> ImportedContentSummary {
        let manifest = ImportedContentManifest.read(from: directory)
        guard !manifest.entries.isEmpty else { return ImportedContentSummary(scenarioIDs: []) }
        let active = manifest.activeEntries(bundled: bundledIndex(), in: directory)
        return ImportedContentSummary(scenarioIDs: active.map { ScenarioID(rawValue: $0.entry.scenarioId) })
    }

    // MARK: Reading the chosen files

    private static func readSource(at url: URL) throws(ContentImportFailure) -> Data {
        guard url.isFileURL else { throw .invalid(issueCount: 1) }
        let data: Data
        do {
            // Memory-mapped so that an oversized file is rejected on size, not read into memory first.
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw .unreadable
        }
        guard data.count <= readCeiling else { throw .invalid(issueCount: 1) }
        return data
    }

    // MARK: Validation

    /// Copies the bytes into a staging folder so the loader validates exactly the bytes that will be
    /// stored, whatever happens to the learner's original file in the meantime.
    private func stage(_ sources: [Data], in staging: URL) throws(ContentImportFailure) -> [URL] {
        var urls: [URL] = []
        for (index, data) in sources.enumerated() {
            let url = staging.appending(path: "\(index).json", directoryHint: .notDirectory)
            do {
                try data.write(to: url, options: [.atomic, .completeFileProtection])
            } catch {
                throw .couldNotSave
            }
            urls.append(url)
        }
        return urls
    }

    /// Returns the scenario id of each staged file, or throws if the batch must be rejected.
    private func validate(_ staged: [URL]) throws(ContentImportFailure) -> [ScenarioID] {
        var ids: [ScenarioID] = []
        var issueCount = 0
        for url in staged {
            let alone = loader.load(files: [url], expectedLanguage: language)
            issueCount += alone.issues.count
            if let scenario = alone.scenarios.first {
                ids.append(scenario.id)
            } else if alone.issues.isEmpty {
                issueCount += 1
            }
        }
        guard issueCount == 0 else { throw .invalid(issueCount: issueCount) }

        // The catalog the learner would end up with: the imports first, then every bundled file whose
        // scenario is not being replaced, so duplicate ids across files are caught by the validator.
        let replaced = Set(ids)
        let keptBundled = bundledIndex().filter { file in
            guard let id = file.scenarioID else { return true }
            return !replaced.contains(id)
        }.map(\.url)
        let combined = loader.load(files: staged + keptBundled, expectedLanguage: language)

        let ownIssues = combined.issues.filter { $0.fileIndex < staged.count }.count
        // The bundled files come later, so an import that collides with them shows up as a new issue
        // on the bundled side. Issues the bundled files already had on their own are not the
        // importer's concern.
        let alreadyThere = Set(loader.load(files: keptBundled, expectedLanguage: language).issues)
        let causedByImport = combined.issues.filter { issue in
            guard issue.fileIndex >= staged.count else { return false }
            let shifted = ContentIssue(
                fileIndex: issue.fileIndex - staged.count,
                scenarioID: issue.scenarioID,
                itemID: issue.itemID,
                rule: issue.rule
            )
            return !alreadyThere.contains(shifted)
        }.count
        guard ownIssues + causedByImport == 0 else {
            throw .invalid(issueCount: ownIssues + causedByImport)
        }
        let present = Set(combined.scenarios.map(\.id))
        guard replaced.isSubset(of: present) else { throw .invalid(issueCount: 1) }
        return ids
    }

    // MARK: Persistence

    private func makeStagingFolder() throws(ContentImportFailure) -> URL {
        let staging = directory.appending(
            path: Self.stagingPrefix + UUID().uuidString,
            directoryHint: .isDirectory
        )
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // A crash mid-import can leave a staging folder behind; nothing else ever reads one.
            let leftovers = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for leftover in leftovers where leftover.lastPathComponent.hasPrefix(Self.stagingPrefix) {
                try FileManager.default.removeItem(at: leftover)
            }
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        } catch {
            throw .couldNotSave
        }
        return staging
    }

    /// Writes the validated files, then the manifest last. A file with no manifest entry is ignored,
    /// so a failure part-way leaves the previous manifest, and so the previous state, in force.
    private func persist(_ sources: [Data], scenarioIDs: [ScenarioID]) throws(ContentImportFailure) {
        let bundled = bundledIndex()
        var newEntries: [ImportedContentManifest.Entry] = []
        for (data, id) in zip(sources, scenarioIDs) {
            let name = ImportedContentManifest.fileName(for: id)
            do {
                try data.write(
                    to: directory.appending(path: name, directoryHint: .notDirectory),
                    options: [.atomic, .completeFileProtection]
                )
            } catch {
                throw .couldNotSave
            }
            let replaces = bundled.first { $0.scenarioID == id }?.sha256
            newEntries.append(
                ImportedContentManifest.Entry(
                    scenarioId: id.rawValue,
                    fileName: name,
                    replacesBundledSHA256: replaces
                )
            )
        }
        let replacedIDs = Set(newEntries.map(\.scenarioId))
        let kept = ImportedContentManifest.read(from: directory).entries.filter { !replacedIDs.contains($0.scenarioId) }
        let merged = (kept + newEntries).sorted { $0.scenarioId < $1.scenarioId }
        try ImportedContentManifest(entries: merged).write(to: directory)
    }

    private static func removeIfPresent(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return
        }
    }

    private func bundledIndex() -> [BundledContentFile] {
        guard let bundledDirectory, let urls = BundleContentLoader.jsonFiles(in: bundledDirectory) else { return [] }
        return BundledContentFile.index(urls, loader: loader, language: language)
    }
}
