/// Where a lesson sits in the course: its level and its place within that level (docs/DECISIONS.md 039).
public struct Level: Sendable, Equatable {
    /// Starts at 1. Every lesson with the same number carries the same `title`.
    public let number: Int
    public let title: String
    /// Starts at 1; orders lessons within the level.
    public let position: Int

    public init(number: Int, title: String, position: Int) {
        self.number = number
        self.title = title
        self.position = position
    }
}
