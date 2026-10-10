import BLTProgress
import Testing

struct ExamHistoryTests {
    private typealias Contract = ExamResultStoreContract

    @Test func bestOfNothingIsNil() {
        #expect(ExamHistory.best(in: []) == nil)
    }

    @Test func bestComparesTheShareNotTheCount() {
        let moreRight = Contract.attempt(day: 1, correct: 70, total: 100)
        let higherShare = Contract.attempt(day: 2, correct: 40, total: 50)
        #expect(ExamHistory.best(in: [moreRight, higherShare]) == higherShare)
    }

    @Test func latestWinsAnExactTie() {
        let earlier = Contract.attempt(day: 1, correct: 80, total: 100)
        let later = Contract.attempt(day: 2, correct: 40, total: 50)
        #expect(ExamHistory.best(in: [earlier, later]) == later)
        #expect(ExamHistory.best(in: [later, earlier]) == earlier)
    }

    @Test func anAttemptWithNoQuestionsCountsAsZero() {
        let empty = Contract.attempt(day: 2, correct: 0, total: 0, passed: false, levels: [])
        let weak = Contract.attempt(day: 1, correct: 1, total: 100, passed: false)
        #expect(ExamHistory.best(in: [weak, empty]) == weak)
        #expect(ExamHistory.best(in: [empty]) == empty)
    }

    @Test func hasPassedLooksAtThePassedFlag() {
        let failed = Contract.attempt(passed: false)
        let passed = Contract.attempt(day: 1, passed: true)
        #expect(!ExamHistory.hasPassed(in: []))
        #expect(!ExamHistory.hasPassed(in: [failed]))
        #expect(ExamHistory.hasPassed(in: [failed, passed]))
    }

    @Test func appendingDropsTheOldestBeyondTheCap() {
        let full = (0..<20).map { Contract.attempt(day: $0) }
        let extra = Contract.attempt(day: 20)
        let result = ExamHistory.appending(extra, to: full)
        #expect(result.count == 20)
        #expect(result.first == full[1])
        #expect(result.last == extra)
    }
}
