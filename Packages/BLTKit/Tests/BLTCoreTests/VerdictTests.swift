import BLTCore
import Testing

struct VerdictTests {
    @Test func outcomeMapsAllThreeVerdicts() {
        #expect(Verdict.correct.outcome == .correct)
        #expect(Verdict.wrongRegister(correct: "zz").outcome == .wrongRegister)
        #expect(Verdict.notQuite(correct: "zz").outcome == .wrong)
    }

    @Test func registerAndAddresseeRawValuesMatchContentSchema() {
        #expect(Register.allCases.map(\.rawValue) == ["casual", "respectful", "neutral"])
        #expect(Addressee.allCases.map(\.rawValue) == ["male", "female", "any"])
        #expect(ReviewStatus.allCases.map(\.rawValue) == ["unreviewed", "reviewed"])
    }
}
