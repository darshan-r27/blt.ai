import BLTCatalog
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
