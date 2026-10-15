/// Persistence for the one device-wide `PracticePreferences` value.
public protocol PracticePreferencesStore: Sendable {
    /// `PracticePreferences.standard` when nothing has been saved yet.
    func load() async throws(PracticePreferencesError) -> PracticePreferences

    /// Replaces the saved preferences. Fails, changing nothing, when the existing file is damaged or from
    /// a newer version of the app.
    func save(_ preferences: PracticePreferences) async throws(PracticePreferencesError)
}
