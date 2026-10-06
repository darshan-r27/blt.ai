/// The only attempt result that Scheduler and ProgressStore ever see.
/// v2 voice scoring maps into this type too, so pronunciation can never reach scheduling.
public enum Outcome: String, Sendable, Codable, CaseIterable {
    case correct
    case wrongRegister
    case wrong
}
