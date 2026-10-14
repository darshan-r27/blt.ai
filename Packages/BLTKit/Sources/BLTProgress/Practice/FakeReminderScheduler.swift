/// A `ReminderScheduling` that keeps everything in memory and records what it was asked to do. Behaves like
/// the real scheduler: a new plan replaces both reminder slots, and nothing is scheduled without permission.
public actor FakeReminderScheduler: ReminderScheduling {
    private var status: ReminderAuthorization
    private let grantsPermissionWhenAsked: Bool
    private var pending: [PlannedReminder] = []

    /// Every plan passed to `schedule`, including ones ignored for lack of permission.
    public private(set) var scheduledPlans: [ReminderPlan] = []
    public private(set) var cancelAllCount = 0
    public private(set) var authorizationRequestCount = 0

    /// - Parameters:
    ///   - status: The permission state to start in.
    ///   - grantsPermissionWhenAsked: What the learner answers when `requestAuthorization` is called.
    public init(status: ReminderAuthorization = .authorized, grantsPermissionWhenAsked: Bool = true) {
        self.status = status
        self.grantsPermissionWhenAsked = grantsPermissionWhenAsked
    }

    public var authorizationStatus: ReminderAuthorization {
        status
    }

    public func requestAuthorization() async -> Bool {
        authorizationRequestCount += 1
        if status == .notDetermined {
            status = grantsPermissionWhenAsked ? .authorized : .denied
        }
        return status == .authorized
    }

    public func schedule(_ plan: ReminderPlan) async {
        scheduledPlans.append(plan)
        guard status == .authorized else {
            return
        }
        pending = plan.reminders.sorted { $0.fireDate < $1.fireDate }
    }

    public func cancelAll() async {
        cancelAllCount += 1
        pending = []
    }

    public func pendingReminders() async -> [PlannedReminder] {
        pending
    }
}
