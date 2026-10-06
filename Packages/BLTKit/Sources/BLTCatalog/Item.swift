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
        reviewStatus: ReviewStatus
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
    }
}
