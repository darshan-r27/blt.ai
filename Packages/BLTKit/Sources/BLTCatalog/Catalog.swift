import BLTCore

public struct Catalog: Sendable, Equatable {
    public let scenarios: [Scenario]
    public let issues: [ContentIssue]

    public init(scenarios: [Scenario], issues: [ContentIssue]) {
        self.scenarios = scenarios
        self.issues = issues
    }

    public func item(_ id: ItemID) -> Item? {
        for scenario in scenarios {
            if let found = scenario.items.first(where: { $0.id == id }) { return found }
        }
        return nil
    }

    public var allItemIDs: Set<ItemID> {
        Set(scenarios.flatMap { $0.items.map(\.id) })
    }
}
