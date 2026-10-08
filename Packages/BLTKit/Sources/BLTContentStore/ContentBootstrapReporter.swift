import BLTCore
import Foundation
import os

/// Writes a short, safe summary of content problems to the unified log: counts, plus item IDs
/// marked private. Never a path, a content string or a rule's payload (`ContentIssue` has none).
public struct ContentBootstrapReporter: Sendable {
    /// Upper bound on IDs written to one log line.
    static let maxLoggedIDs = 20

    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "ai.blt.app", category: "content")) {
        self.logger = logger
    }

    public func report(_ result: ContentBootstrapResult) {
        guard result.hasProblems else { return }
        if !result.directoryReadable {
            logger.error("Bundled content folder could not be read; starting with no content.")
        }
        let skipped = result.skippedItemCount
        let other = result.fileOrScenarioIssueCount
        let files = result.fileCount
        let scenarios = result.catalog.scenarios.count
        logger.error(
            """
            Content problems: \(skipped, privacy: .public) items skipped, \
            \(other, privacy: .public) file or scenario issues, \
            \(scenarios, privacy: .public) scenarios loaded from \(files, privacy: .public) files.
            """
        )
        let ids = Self.loggedIDs(result.skippedItemIDs)
        if !ids.isEmpty {
            logger.error("Skipped item IDs: \(ids, privacy: .private)")
        }
    }

    static func loggedIDs(_ ids: [ItemID]) -> String {
        let shown = ids.prefix(maxLoggedIDs).map(\.rawValue).joined(separator: ", ")
        return ids.count > maxLoggedIDs ? shown + ", ..." : shown
    }
}
