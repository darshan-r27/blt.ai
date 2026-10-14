/// One of the two reminders. Each has a fixed notification identifier, so a new plan replaces the old one
/// instead of piling up beside it.
public enum ReminderSlot: String, Sendable, Equatable, CaseIterable, Comparable {
    /// 20 hours after the last finished session.
    case first
    /// 23 hours after the last finished session.
    case second

    /// The identifier handed to the system notification center.
    public var identifier: String {
        "ai.blt.reminder.\(rawValue)"
    }

    /// Hours after the last finished session when this reminder is due, before quiet hours move it.
    public var hoursAfterSession: Int {
        switch self {
        case .first: 20
        case .second: 23
        }
    }

    public init?(identifier: String) {
        guard let match = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = match
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.hoursAfterSession < rhs.hoursAfterSession
    }
}
