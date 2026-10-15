import BLTCore

/// What a reminder may say about the learner: the language being learned and the streak length. Nothing
/// else goes into notification text, because a lock screen is public.
public struct ReminderContext: Sendable, Equatable {
    public let language: CourseLanguage
    /// The streak in days when the plan is made. Zero or less means no streak to mention.
    public let streakLength: Int

    public init(language: CourseLanguage, streakLength: Int) {
        self.language = language
        self.streakLength = streakLength
    }
}
