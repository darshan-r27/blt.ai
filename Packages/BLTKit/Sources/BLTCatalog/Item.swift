import BLTCore

public struct Item: Sendable, Equatable, Identifiable {
    public let id: ItemID
    public let scenarioID: ScenarioID
    public let sourcePrompt: String
    public let register: Register
    public let addressee: Addressee
    public let canonical: String
    public let acceptedAnswers: [String]
    /// The same sentence in the other spoken register. `nil` exactly when `register == .neutral`.
    public let registerVariant: String?
    /// Two when a register variant exists, otherwise three, so a question always has four options.
    public let distractors: [String]
    public let tokens: [Token]
    public let note: String?
    public let reviewStatus: ReviewStatus
    /// The canonical answer in the lesson language's own script, kept so audio can be generated later
    /// (docs/DECISIONS.md 040, 044). Not shown in the app. `nil` for content that predates the field.
    public let script: String?

    public init(
        id: ItemID,
        scenarioID: ScenarioID,
        sourcePrompt: String,
        register: Register,
        addressee: Addressee,
        canonical: String,
        acceptedAnswers: [String],
        registerVariant: String?,
        distractors: [String],
        tokens: [Token],
        note: String?,
        reviewStatus: ReviewStatus,
        script: String? = nil
    ) {
        self.id = id
        self.scenarioID = scenarioID
        self.sourcePrompt = sourcePrompt
        self.register = register
        self.addressee = addressee
        self.canonical = canonical
        self.acceptedAnswers = acceptedAnswers
        self.registerVariant = registerVariant
        self.distractors = distractors
        self.tokens = tokens
        self.note = note
        self.reviewStatus = reviewStatus
        self.script = script
    }
}
