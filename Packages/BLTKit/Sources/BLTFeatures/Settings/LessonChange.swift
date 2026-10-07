/// What changed in the lessons, reported by Settings to the owner of the catalog so it can reload.
public enum LessonChange: Sendable, Equatable {
    /// Lessons were imported; `scenarioCount` is how many imported scenarios are now in use.
    case imported(scenarioCount: Int)
    /// All imported lessons were removed; the bundled lessons are used again.
    case removed
}
