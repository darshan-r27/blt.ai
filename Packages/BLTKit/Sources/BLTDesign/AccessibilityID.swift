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
    public static let introStart = "intro.start"
    public static let nameField = "name.field"
    public static let nameContinue = "name.continue"
    public static let nameError = "name.error"
    public static let greeting = "home.greeting"
    public static let settingsChangeName = "settings.changeName"
    public static let changeNameField = "changeName.field"
    public static let changeNameSave = "changeName.save"
    public static let changeNameCancel = "changeName.cancel"

    public static func scenarioCard(_ scenarioID: String) -> String {
        "scenario.card.\(scenarioID)"
    }
}
