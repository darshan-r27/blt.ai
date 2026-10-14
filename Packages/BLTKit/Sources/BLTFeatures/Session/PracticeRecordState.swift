/// Where recording the finished chapter in the practice log has got to, as the summary screen sees it.
enum PracticeRecordState: Equatable {
    /// Nothing recorded (yet): the session has no answers, or the write is still in flight.
    case none
    case recorded(PracticeOutcome)
    /// The log could not be read or written. The learner's answers are unaffected; the summary says so calmly.
    case failed
}
