import BLTCore
import Foundation

public struct ReviewState: Sendable, Equatable, Codable {
    public var itemID: ItemID
    public var repetitions: Int
    public var intervalDays: Int
    public var easeFactor: Double
    public var due: Date
    public var lastOutcome: Outcome
    public var lastReviewed: Date

    public init(
        itemID: ItemID,
        repetitions: Int,
        intervalDays: Int,
        easeFactor: Double,
        due: Date,
        lastOutcome: Outcome,
        lastReviewed: Date
    ) {
        self.itemID = itemID
        self.repetitions = repetitions
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.due = due
        self.lastOutcome = lastOutcome
        self.lastReviewed = lastReviewed
    }

    public var isLearned: Bool { repetitions >= 2 && lastOutcome == .correct }

    public func isDue(at now: Date) -> Bool { due <= now }
}
