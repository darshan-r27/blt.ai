import BLTCore

public struct Scenario: Sendable, Equatable, Identifiable {
    public let id: ScenarioID
    public let title: String
    public let subtitle: String
    public let romanisationNote: String?
    public let items: [Item]
    /// `nil` for a file that does not say where it sits in the course (for example an older import).
    public let level: Level?

    public init(
        id: ScenarioID,
        title: String,
        subtitle: String,
        romanisationNote: String?,
        items: [Item],
        level: Level? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.romanisationNote = romanisationNote
        self.items = items
        self.level = level
    }
}
