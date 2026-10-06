import BLTCore
import Foundation

public struct AttemptRecord: Sendable, Equatable, Codable {
    public let itemID: ItemID
    public let outcome: Outcome
    public let date: Date

    public init(itemID: ItemID, outcome: Outcome, date: Date) {
        self.itemID = itemID
        self.outcome = outcome
        self.date = date
    }
}
