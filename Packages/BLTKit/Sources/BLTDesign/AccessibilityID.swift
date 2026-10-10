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
    public static let settingsImportLessons = "settings.importLessons"
    public static let settingsRemoveImported = "settings.removeImported"
    public static let settingsImportStatus = "settings.importStatus"

    // Two-way course (DECISIONS 042, 043). Added up front so the onboarding, Home and Settings chunks
    // do not collide on this file. A language is passed as its raw value (`CourseLanguage.rawValue`).
    public static let languageContinue = "language.continue"
    public static let homeLanguage = "home.language"
    public static let homeContinueLesson = "home.continueLesson"
    public static let homeOtherLessons = "home.otherLessons"
    public static let settingsLanguage = "settings.language"
    public static let settingsLanguageConfirm = "settings.language.confirm"
    public static let settingsLanguageCancel = "settings.language.cancel"

    public static func scenarioCard(_ scenarioID: String) -> String {
        "scenario.card.\(scenarioID)"
    }

    public static func languageOption(_ language: String) -> String {
        "language.option.\(language)"
    }

    public static func homeLevel(_ number: Int) -> String {
        "home.level.\(number)"
    }

    public static func settingsLanguageOption(_ language: String) -> String {
        "settings.language.option.\(language)"
    }
}
