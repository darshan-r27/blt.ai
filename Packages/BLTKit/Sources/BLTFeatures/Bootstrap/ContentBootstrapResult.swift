import BLTCatalog
import BLTCore

/// What loading the bundled content produced, as plain data. The app decides what to do about
/// problems (assert in DEBUG, skip and log in release); nothing here crashes or logs.
public struct ContentBootstrapResult: Sendable, Equatable {
    /// Everything that validated. Always usable, even when `hasProblems` is true.
    public let catalog: Catalog
    /// How many `*.json` files were found and handed to the loader.
    public let fileCount: Int
    /// False when the content directory itself could not be located or listed. The catalog is then
    /// empty, and that is a failure to report, not "no content".
    public let directoryReadable: Bool

    public init(catalog: Catalog, fileCount: Int, directoryReadable: Bool) {
        self.catalog = catalog
        self.fileCount = fileCount
        self.directoryReadable = directoryReadable
    }

    public var issues: [ContentIssue] { catalog.issues }

    /// Items that were left out, counted once each however many rules they broke.
    public var skippedItemIDs: [ItemID] {
        Array(Set(issues.compactMap(\.itemID))).sorted { $0.rawValue < $1.rawValue }
    }

    public var skippedItemCount: Int { skippedItemIDs.count }

    /// Issues that name no item: an unreadable or malformed file, an empty scenario, and so on.
    public var fileOrScenarioIssueCount: Int { issues.filter { $0.itemID == nil }.count }

    public var hasProblems: Bool { !directoryReadable || !issues.isEmpty }
}
