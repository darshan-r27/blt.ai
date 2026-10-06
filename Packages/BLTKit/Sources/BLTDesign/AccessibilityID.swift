public enum AccessibilityID {
    public static let feedbackCorrect = "feedback.correct"
    public static let feedbackWrongRegister = "feedback.wrongRegister"
    public static let feedbackNotQuite = "feedback.notQuite"
    public static let badgeUnreviewed = "badge.unreviewed"
    public static let continueButton = "continue.button"
    public static let progressRegisterAccuracy = "progress.registerAccuracy"
    public static let progressLearned = "progress.learned"
    public static let progressDue = "progress.due"
    public static let settingsReset = "settings.reset"
    public static let endSessionButton = "session.end.button"
    public static let endSessionConfirm = "session.end.confirm"
    public static let endSessionKeepGoing = "session.end.keepGoing"

    public static func scenarioCard(_ scenarioID: String) -> String {
        "scenario.card.\(scenarioID)"
    }
}
