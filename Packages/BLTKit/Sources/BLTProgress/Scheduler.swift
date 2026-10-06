import BLTCore
import Foundation

/// Pure: the same input always gives the same output. `previous == nil` means the first ever attempt.
public protocol Scheduler: Sendable {
    func review(_ previous: ReviewState?, itemID: ItemID, outcome: Outcome, at now: Date) -> ReviewState
}
