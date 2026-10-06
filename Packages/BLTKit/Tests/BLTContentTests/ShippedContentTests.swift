import BLTCatalog
import BLTCore
import Foundation
import Testing

/// Conformance of the content that ships in `content/*.json`, loaded through the real `ContentLoader`.
struct ShippedContentTests {
    private let expectedScenarioCount = 5
    private let expectedItemsPerScenario = 20

    /// Repo root, found from this file's path: Packages/BLTKit/Tests/BLTContentTests/<file>.
    private var contentDirectory: URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appending(path: "content", directoryHint: .isDirectory)
    }

    private func contentFiles() throws -> [URL] {
        let entries = try FileManager.default.contentsOfDirectory(at: contentDirectory, includingPropertiesForKeys: nil)
        return entries
            .filter { $0.isFileURL && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func describe(_ issue: ContentIssue, files: [URL]) -> String {
        let name = files.indices.contains(issue.fileIndex) ? files[issue.fileIndex].lastPathComponent : "?"
        let scenario = issue.scenarioID?.rawValue ?? "-"
        let item = issue.itemID?.rawValue ?? "-"
        return "file \(issue.fileIndex) (\(name)), scenario \(scenario), item \(item), rule \(issue.rule)"
    }

    /// Counts the `reviewStatus` strings written in the raw JSON, independent of the loader.
    private func rawReviewStatusCounts(files: [URL]) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for file in files where file.isFileURL {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
            let root = try #require(object as? [String: Any])
            let items = try #require(root["items"] as? [[String: Any]])
            for item in items {
                let status = item["reviewStatus"] as? String
                let key = status == "unreviewed" || status == "reviewed" ? (status ?? "") : "other"
                counts[key, default: 0] += 1
            }
        }
        return counts
    }

    @Test func shippedContentLoadsWithoutIssues() throws {
        let files = try contentFiles()
        let catalog = ContentLoader(limits: .default).load(files: files)
        let lines = catalog.issues.map { describe($0, files: files) }
        #expect(
            catalog.issues.isEmpty,
            Comment(rawValue: "Content issues (fix in content/, not in tests):\n" + lines.joined(separator: "\n"))
        )
    }

    @Test func hasExactlyFiveScenarioFilesAndFiveScenarios() throws {
        let files = try contentFiles()
        #expect(files.count == expectedScenarioCount)
        let catalog = ContentLoader(limits: .default).load(files: files)
        #expect(catalog.scenarios.count == expectedScenarioCount)
    }

    @Test func everyScenarioHasTwentyItemsAndATitle() throws {
        let catalog = ContentLoader(limits: .default).load(files: try contentFiles())
        for scenario in catalog.scenarios {
            #expect(
                scenario.items.count == expectedItemsPerScenario,
                "scenario \(scenario.id.rawValue) has \(scenario.items.count) items"
            )
            let title = scenario.title.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!title.isEmpty, "scenario \(scenario.id.rawValue) has an empty title")
        }
    }

    @Test func everyItemHasTokens() throws {
        let catalog = ContentLoader(limits: .default).load(files: try contentFiles())
        for scenario in catalog.scenarios {
            for item in scenario.items {
                #expect(!item.tokens.isEmpty, "item \(item.id.rawValue) has no tokens")
            }
        }
    }

    @Test func itemIDsAreUniqueAcrossTheCatalog() throws {
        let catalog = ContentLoader(limits: .default).load(files: try contentFiles())
        let ids = catalog.scenarios.flatMap { $0.items.map(\.id.rawValue) }
        #expect(Set(ids).count == ids.count)
        #expect(catalog.allItemIDs.count == ids.count)
    }

    /// The type only allows two statuses, so check the loader did not default anything: the counts of each
    /// status in the raw JSON must match the counts in the loaded catalog, and no raw value may be anything else.
    @Test func reviewStatusIsNeverSilentlyDefaulted() throws {
        let files = try contentFiles()
        let catalog = ContentLoader(limits: .default).load(files: files)
        let loaded = catalog.scenarios.flatMap(\.items)
        let raw = try rawReviewStatusCounts(files: files)

        let other = raw["other"] ?? 0
        #expect(other == 0, "raw JSON has \(other) items with a missing or unknown reviewStatus")
        #expect(loaded.filter { $0.reviewStatus == .unreviewed }.count == (raw["unreviewed"] ?? 0))
        #expect(loaded.filter { $0.reviewStatus == .reviewed }.count == (raw["reviewed"] ?? 0))
        #expect(loaded.count == (raw["unreviewed"] ?? 0) + (raw["reviewed"] ?? 0))
    }
}
