import BLTCore

public struct ProgressSnapshot: Sendable, Equatable {
    public var reviews: [ItemID: ReviewState]
    public var attempts: [AttemptRecord]

    public init(reviews: [ItemID: ReviewState], attempts: [AttemptRecord]) {
        self.reviews = reviews
        self.attempts = attempts
    }

    public static let empty = ProgressSnapshot(reviews: [:], attempts: [])
}
