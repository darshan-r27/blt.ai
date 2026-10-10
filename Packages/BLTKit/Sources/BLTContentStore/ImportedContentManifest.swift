import BLTCatalog
import BLTCore
import CryptoKit
import Foundation

/// A bundled content file, as the layering rules need to see it: where it is, a hash of its bytes
/// and the scenario id it carries.
struct BundledContentFile: Sendable {
    let url: URL
    /// Hex SHA-256 of the file's bytes; `nil` when the file could not be read.
    let sha256: String?
    /// `nil` when the file yields no scenario (it is broken); such a file can never be replaced.
    let scenarioID: ScenarioID?

    /// Hashes and identifies each file. Files are loaded one at a time so each id is known. A file of
    /// the other course yields no scenario (it is broken for this course), so it is never replaced.
    static func index(_ urls: [URL], loader: ContentLoader, language: CourseLanguage?) -> [BundledContentFile] {
        urls.map { url in
            BundledContentFile(
                url: url,
                sha256: ImportedContentManifest.sha256Hex(ofFileAt: url),
                scenarioID: loader.load(files: [url], expectedLanguage: language).scenarios.first?.id
            )
        }
    }
}

private enum EntryCodingKeys: String, CodingKey {
    case scenarioId, fileName, replacesBundledSHA256
}

/// The record of which imported files are in the import folder, kept in `imported.json` beside them.
///
/// Written last and atomically, so a file without an entry (a crash mid-import) is simply ignored.
/// A missing or corrupt manifest reads as "nothing imported": it is never an error for the learner.
struct ImportedContentManifest: Sendable, Equatable {
    struct Entry: Sendable, Equatable, Codable {
        let scenarioId: String
        /// Derived from a hash of the scenario id; see `fileName(for:)`.
        let fileName: String
        /// Hex SHA-256 of the bundled file this import replaced; `nil` when the id was new.
        let replacesBundledSHA256: String?

        init(scenarioId: String, fileName: String, replacesBundledSHA256: String?) {
            self.scenarioId = scenarioId
            self.fileName = fileName
            self.replacesBundledSHA256 = replacesBundledSHA256
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: EntryCodingKeys.self)
            scenarioId = try container.decode(String.self, forKey: .scenarioId)
            fileName = try container.decode(String.self, forKey: .fileName)
            replacesBundledSHA256 = try container.decodeIfPresent(String.self, forKey: .replacesBundledSHA256)
        }

        /// Encodes a missing hash as an explicit `null` rather than leaving the key out.
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: EntryCodingKeys.self)
            try container.encode(scenarioId, forKey: .scenarioId)
            try container.encode(fileName, forKey: .fileName)
            try container.encode(replacesBundledSHA256, forKey: .replacesBundledSHA256)
        }
    }

    private struct Envelope: Codable {
        let entries: [Entry]
    }

    static let fileName = "imported.json"
    private static let maxManifestBytes = 1_048_576
    private static let hashedNameLength = 16

    let entries: [Entry]

    static let empty = ImportedContentManifest(entries: [])

    // MARK: Names and hashes

    /// A stable, path-safe file name for a scenario id: the first 16 hex characters of its SHA-256.
    /// Never built from the user's file name or the id's own characters.
    static func fileName(for scenarioID: ScenarioID) -> String {
        let digest = hex(SHA256.hash(data: Data(scenarioID.rawValue.utf8)))
        return String(digest.prefix(hashedNameLength)) + ".json"
    }

    /// True only for names this store could have produced. Guards against a tampered manifest
    /// pointing at another file or climbing out of the folder.
    static func isStoredFileName(_ name: String) -> Bool {
        guard name.hasSuffix(".json") else { return false }
        let stem = name.dropLast(".json".count)
        guard stem.count == hashedNameLength else { return false }
        return stem.allSatisfy { $0.isASCII && ($0.isNumber || ("a"..."f").contains($0)) }
    }

    static func sha256Hex(of data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    static func sha256Hex(ofFileAt url: URL) -> String? {
        guard url.isFileURL else { return nil }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return sha256Hex(of: data)
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Reading and writing

    static func url(in directory: URL) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Reads the manifest; anything wrong with it (missing, oversized, undecodable) is `.empty`.
    /// Entries whose file name this store could not have produced are dropped.
    static func read(from directory: URL) -> ImportedContentManifest {
        let url = url(in: directory)
        guard url.isFileURL,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count <= maxManifestBytes,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else { return .empty }
        var seen: Set<String> = []
        let valid = envelope.entries.filter { entry in
            isStoredFileName(entry.fileName) && seen.insert(entry.scenarioId).inserted
        }
        return ImportedContentManifest(entries: valid)
    }

    func write(to directory: URL) throws(ContentImportFailure) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Envelope(entries: entries))
            try data.write(to: Self.url(in: directory), options: [.atomic, .completeFileProtection])
        } catch {
            throw .couldNotSave
        }
    }

    // MARK: Layering

    /// The entries that currently apply, each with the URL of its stored file.
    ///
    /// An import that replaced a bundled file is dropped when that bundled file has changed or gone
    /// (a newer build shipped different content), and an import of a new id is dropped when a bundled
    /// scenario has since taken that id. A listed file that is missing from disk is dropped too, so
    /// the bundled scenario keeps working.
    func activeEntries(bundled: [BundledContentFile], in directory: URL) -> [(entry: Entry, url: URL)] {
        entries.compactMap { entry in
            let bundledMatch = bundled.first { $0.scenarioID?.rawValue == entry.scenarioId }
            if let recorded = entry.replacesBundledSHA256 {
                guard let current = bundledMatch?.sha256, current == recorded else { return nil }
            } else if bundledMatch != nil {
                return nil
            }
            let url = directory.appending(path: entry.fileName, directoryHint: .notDirectory)
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                return nil
            }
            return (entry, url)
        }
    }
}
