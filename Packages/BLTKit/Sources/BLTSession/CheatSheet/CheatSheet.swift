import BLTCore

/// A revision list for one topic: its distinct words in the order the topic teaches them.
public struct CheatSheet: Sendable, Equatable {
    public let scenarioID: ScenarioID
    public let entries: [CheatSheetEntry]

    public init(scenarioID: ScenarioID, entries: [CheatSheetEntry]) {
        self.scenarioID = scenarioID
        self.entries = entries
    }
}
