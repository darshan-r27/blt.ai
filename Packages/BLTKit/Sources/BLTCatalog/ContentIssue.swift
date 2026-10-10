import BLTCore

/// A content problem. Closed on purpose: no free text, no file paths, so an issue can be logged safely.
public struct ContentIssue: Sendable, Hashable {
    public enum Field: String, Sendable, Hashable, CaseIterable {
        case scenarioId, title, subtitle, id, sourcePrompt, register, addressee, canonical
        case acceptedAnswers, registerVariant, distractors, tokens, note, reviewStatus, level, language, script
    }

    public enum Rule: Sendable, Hashable {
        case notAFileURL, unreadableFile, fileTooLarge, malformedJSON
        case missingField(Field), emptyField(Field), fieldTooLong(Field)
        case nativeScriptInField(Field), unknownValue(Field)
        case wrongDistractorCount, registerVariantMismatch, canonicalNotAccepted, otherOptionAccepted
        case wrongAcceptedCount, duplicateOptionText, duplicateItemID, duplicateScenarioID
        case tokenNotInCanonical, tooManyItems, emptyScenario
        case duplicateSourcePrompt, duplicateCanonical, duplicateAcceptedAnswer
        case invalidLevelNumber, invalidLevelPosition, levelTitleMismatch
        case scriptMissingNativeLetters, latinLettersInScript
        /// The lesson's `language` is not the course being loaded (DECISIONS 044).
        case wrongLanguage
    }

    public let fileIndex: Int
    public let scenarioID: ScenarioID?
    public let itemID: ItemID?
    public let rule: Rule

    public init(fileIndex: Int, scenarioID: ScenarioID?, itemID: ItemID?, rule: Rule) {
        self.fileIndex = fileIndex
        self.scenarioID = scenarioID
        self.itemID = itemID
        self.rule = rule
    }
}
