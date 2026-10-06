import BLTCore

public struct Scenario: Sendable, Equatable, Identifiable {
    public let id: ScenarioID
    public let title: String
    public let subtitle: String
    public let romanisationNote: String?
    public let items: [Item]

    public init(id: ScenarioID, title: String, subtitle: String, romanisationNote: String?, items: [Item]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.romanisationNote = romanisationNote
        self.items = items
    }
}
