import BLTCore

/// What the app knows about the person using it: a display name and the language they are learning
/// (DECISIONS 030, 043).
///
/// The initialiser stores exactly what it is given. Run user input through `ProfileNameValidator` first.
///
/// `learningLanguage` is `nil` until the learner chooses one. Nothing in the app may assume a language
/// for a profile that has none (DECISIONS 043), so there is no default course here.
public struct UserProfile: Sendable, Equatable, Codable {
    public let name: String
    public let learningLanguage: CourseLanguage?

    public init(name: String, learningLanguage: CourseLanguage? = nil) {
        self.name = name
        self.learningLanguage = learningLanguage
    }

    /// A copy with the same name and a different language. `ProfileStore.save` of the copy changes the
    /// stored language; the name is never touched.
    public func withLearningLanguage(_ language: CourseLanguage?) -> UserProfile {
        UserProfile(name: name, learningLanguage: language)
    }
}
