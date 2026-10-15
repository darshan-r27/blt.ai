import BLTProgress

/// When the app may offer the notification permission pre-prompt on its own. Pure, so the rule can be
/// tested without a screen.
enum NotificationsPromptRule {
    /// - Parameters:
    ///   - finishedSessionCount: Finished sessions across both courses, counting the one that just ended.
    ///   - hasAskedBefore: `PracticePreferences.hasAskedForNotifications`.
    ///   - authorization: What the system currently allows.
    /// - Returns: `true` only at the end of the very first finished session, if the learner has not been
    ///   asked before and the system has not been asked either. Exactly the first (not "at least one") so a
    ///   prompt that was swiped away or missed is never repeated at later sessions; the Settings toggle is
    ///   the way back in.
    static func shouldAsk(
        finishedSessionCount: Int,
        hasAskedBefore: Bool,
        authorization: ReminderAuthorization
    ) -> Bool {
        finishedSessionCount == 1 && !hasAskedBefore && authorization == .notDetermined
    }
}
