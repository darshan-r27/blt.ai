import BLTCatalog
import BLTCore
import Foundation

/// Finds the content files in a folder and loads them through `ContentLoader`.
///
/// Only regular files whose name ends in `.json` are loaded, in file-name order, so a run is
/// reproducible. Anything else in the folder is ignored. The folder must be a file URL.
public struct BundleContentLoader: Sendable {
    private let loader: ContentLoader

    public init(loader: ContentLoader = ContentLoader()) {
        self.loader = loader
    }

    /// Loads `content/*.json` (or another folder name) from a bundle's resources. A bundle without
    /// that folder reports `directoryReadable == false`.
    public func load(bundle: Bundle, folder: String = "content") -> ContentBootstrapResult {
        guard let directory = bundle.url(forResource: folder, withExtension: nil) else {
            return Self.unreadable
        }
        return load(directory: directory)
    }

    public func load(directory: URL) -> ContentBootstrapResult {
        guard let files = Self.jsonFiles(in: directory) else { return Self.unreadable }
        let catalog = loader.load(files: files)
        return ContentBootstrapResult(catalog: catalog, fileCount: files.count, directoryReadable: true)
    }

    /// Like `load(bundle:folder:)`, with lesson files the learner imported layered over the bundled
    /// ones. See `load(directory:importedDirectory:)`.
    public func load(bundle: Bundle, importedDirectory: URL, folder: String = "content") -> ContentBootstrapResult {
        guard let directory = bundle.url(forResource: folder, withExtension: nil) else {
            return Self.unreadable
        }
        return load(directory: directory, importedDirectory: importedDirectory)
    }

    /// Loads the bundled files with imported lessons layered on top.
    ///
    /// An imported scenario replaces the bundled one with the same id, or adds a new one; imports
    /// are loaded first so they win any id collision. An import is ignored (the bundled scenario wins)
    /// when it replaced a bundled file that has since changed or gone, or when a new id has since
    /// been taken by a bundled scenario. An imported file that no longer validates is skipped and its
    /// issues are reported in the result. With nothing active the result is exactly `load(directory:)`.
    public func load(directory: URL, importedDirectory: URL) -> ContentBootstrapResult {
        guard let bundledFiles = Self.jsonFiles(in: directory) else { return Self.unreadable }
        let manifest = ImportedContentManifest.read(from: importedDirectory)
        guard !manifest.entries.isEmpty else { return load(directory: directory) }

        let bundled = BundledContentFile.index(bundledFiles, loader: loader)
        let active = manifest.activeEntries(bundled: bundled, in: importedDirectory)
        guard !active.isEmpty else { return load(directory: directory) }

        var skippedIssues: [ContentIssue] = []
        var importedURLs: [URL] = []
        var importedIDs: Set<ScenarioID> = []
        for (position, candidate) in active.enumerated() {
            let alone = loader.load(files: [candidate.url])
            let carriesExpectedID = alone.scenarios.first?.id.rawValue == candidate.entry.scenarioId
            if alone.issues.isEmpty && carriesExpectedID {
                importedURLs.append(candidate.url)
                importedIDs.insert(ScenarioID(rawValue: candidate.entry.scenarioId))
            } else {
                skippedIssues += Self.reindexed(alone.issues, to: position, carriesExpectedID: carriesExpectedID)
            }
        }
        guard !importedURLs.isEmpty else {
            let plain = load(directory: directory)
            let catalog = Catalog(scenarios: plain.catalog.scenarios, issues: skippedIssues + plain.catalog.issues)
            return ContentBootstrapResult(catalog: catalog, fileCount: plain.fileCount, directoryReadable: true)
        }

        let keptBundled = bundled.filter { file in
            guard let id = file.scenarioID else { return true }
            return !importedIDs.contains(id)
        }
        let files = importedURLs + keptBundled.map(\.url)
        let loaded = loader.load(files: files)
        let catalog = Catalog(scenarios: loaded.scenarios, issues: skippedIssues + loaded.issues)
        return ContentBootstrapResult(catalog: catalog, fileCount: files.count, directoryReadable: true)
    }

    /// Issues from a skipped imported file, numbered by the file's position among the active imports
    /// (it is not in the final file list). A file that loaded cleanly but carries the wrong scenario
    /// id gets one issue so the skip is never silent.
    private static func reindexed(
        _ issues: [ContentIssue],
        to position: Int,
        carriesExpectedID: Bool
    ) -> [ContentIssue] {
        var result = issues.map {
            ContentIssue(fileIndex: position, scenarioID: $0.scenarioID, itemID: $0.itemID, rule: $0.rule)
        }
        if result.isEmpty && !carriesExpectedID {
            result.append(
                ContentIssue(fileIndex: position, scenarioID: nil, itemID: nil, rule: .unknownValue(.scenarioId))
            )
        }
        return result
    }

    /// The `*.json` regular files directly inside `directory`, sorted by file name; `nil` when
    /// `directory` is not a file URL or cannot be listed. Subfolders are not searched.
    public static func jsonFiles(in directory: URL) -> [URL]? {
        guard directory.isFileURL else { return nil }
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return nil
        }
        return entries
            .filter { $0.pathExtension == "json" && $0.isFileURL && Self.isRegularFile($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    private static var unreadable: ContentBootstrapResult {
        ContentBootstrapResult(
            catalog: Catalog(scenarios: [], issues: []),
            fileCount: 0,
            directoryReadable: false
        )
    }
}
