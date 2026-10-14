/// A `PracticePreferencesStore` that keeps the value in memory. For tests and previews; behaves like
/// `FilePracticePreferencesStore` minus the failure modes that only a disk can have.
public actor InMemoryPracticePreferencesStore: PracticePreferencesStore {
    private var preferences: PracticePreferences

    public init(initial: PracticePreferences = .standard) {
        preferences = initial
    }

    public func load() async throws(PracticePreferencesError) -> PracticePreferences {
        preferences
    }

    public func save(_ preferences: PracticePreferences) async throws(PracticePreferencesError) {
        self.preferences = preferences
    }
}
