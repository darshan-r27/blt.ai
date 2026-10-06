import BLTCore
import Foundation

/// Loads scenario files into a `Catalog`. Never throws: every problem becomes a `ContentIssue`, and valid
/// content survives alongside invalid content. Content files are treated as untrusted input.
public struct ContentLoader: Sendable {
    /// Resource ceilings from the content schema (docs/MVP_PLAN.md section 2).
    public struct Limits: Sendable, Equatable {
        public let maxFileBytes: Int
        public let maxItemsPerFile: Int
        public let maxStringLength: Int

        public init(maxFileBytes: Int, maxItemsPerFile: Int, maxStringLength: Int) {
            self.maxFileBytes = maxFileBytes
            self.maxItemsPerFile = maxItemsPerFile
            self.maxStringLength = maxStringLength
        }

        public static let `default` = Limits(maxFileBytes: 1_048_576, maxItemsPerFile: 200, maxStringLength: 500)
    }

    private struct ReadFailure: Error {
        let rule: ContentIssue.Rule
    }

    private let limits: Limits

    public init(limits: Limits = .default) {
        self.limits = limits
    }

    /// Loads every file in order. `ContentIssue.fileIndex` is the index into `files`.
    /// Scenarios in the result are sorted by id; when ids collide the earlier file wins.
    public func load(files: [URL]) -> Catalog {
        let validator = ContentValidator(limits: limits)
        var scenarios: [Scenario] = []
        var issues: [ContentIssue] = []
        var scenarioIDs: Set<ScenarioID> = []
        var itemIDs: Set<ItemID> = []

        for (index, url) in files.enumerated() {
            do {
                let raw = try readScenario(at: url)
                let result = validator.validate(
                    raw, fileIndex: index, scenarioIDs: &scenarioIDs, itemIDs: &itemIDs
                )
                if let scenario = result.scenario { scenarios.append(scenario) }
                issues.append(contentsOf: result.issues)
            } catch {
                issues.append(ContentIssue(fileIndex: index, scenarioID: nil, itemID: nil, rule: error.rule))
            }
        }
        scenarios.sort { $0.id.rawValue < $1.id.rawValue }
        return Catalog(scenarios: scenarios, issues: issues)
    }

    private func readScenario(at url: URL) throws(ReadFailure) -> RawScenario {
        guard url.isFileURL else { throw ReadFailure(rule: .notAFileURL) }
        let data: Data
        do {
            // Memory-mapped so that an oversized file is rejected on size, not read into memory first.
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ReadFailure(rule: .unreadableFile)
        }
        guard data.count <= limits.maxFileBytes else { throw ReadFailure(rule: .fileTooLarge) }
        do {
            return try JSONDecoder().decode(RawScenario.self, from: data)
        } catch {
            throw ReadFailure(rule: .malformedJSON)
        }
    }
}
