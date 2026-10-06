import BLTCore
import BLTDesign
import Testing

struct FeedbackToneTests {
    @Test func everyOutcomeHasAToneAndWrongIsNeutral() {
        #expect(FeedbackTone(.correct) == .affirm)
        #expect(FeedbackTone(.wrongRegister) == .nudge)
        #expect(FeedbackTone(.wrong) == .neutral)
    }

    @Test func accessibilityIdentifiersAreUnique() {
        let ids = [
            AccessibilityID.feedbackCorrect, AccessibilityID.feedbackWrongRegister, AccessibilityID.feedbackNotQuite,
            AccessibilityID.badgeUnreviewed, AccessibilityID.continueButton, AccessibilityID.progressRegisterAccuracy,
            AccessibilityID.progressLearned, AccessibilityID.progressDue, AccessibilityID.settingsReset
        ]
        #expect(Set(ids).count == ids.count)
        #expect(AccessibilityID.scenarioCard("zz") == "scenario.card.zz")
    }
}
