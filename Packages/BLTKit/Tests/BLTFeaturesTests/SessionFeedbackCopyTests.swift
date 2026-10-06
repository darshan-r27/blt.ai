import BLTCore
import Testing

@testable import BLTFeatures

struct SessionFeedbackCopyTests {
    @Test func respectfulItemChosenCasualSaysWhichFormToUseWithWhom() {
        let copy = SessionFeedbackCopy(
            verdict: .wrongRegister(correct: "zz"),
            item: PreviewCatalog.respectfulItem,
            willReturn: true
        )
        #expect(copy.headline == "Right sentence, wrong register for this person")
        #expect(copy.detail.contains("casual form"))
        #expect(copy.detail.contains("friend"))
        #expect(copy.detail.contains("elder"))
        #expect(copy.detail.contains("respectful form"))
    }

    @Test func notQuiteIsCalmAndSaysTheItemComesBack() {
        let copy = SessionFeedbackCopy(
            verdict: .notQuite(correct: "zz"),
            item: PreviewCatalog.neutralItem,
            willReturn: true
        )
        #expect(copy.headline == "Not quite")
        #expect(copy.detail.contains("come back shortly"))
    }

    @Test func notQuiteDoesNotPromiseAReturnThatWillNotHappen() {
        let copy = SessionFeedbackCopy(
            verdict: .notQuite(correct: "zz"),
            item: PreviewCatalog.neutralItem,
            willReturn: false
        )
        #expect(!copy.detail.contains("come back shortly"))
    }

    @Test func correctIsBrief() {
        let copy = SessionFeedbackCopy(verdict: .correct, item: PreviewCatalog.neutralItem, willReturn: false)
        #expect(copy.headline == "Correct")
    }
}
