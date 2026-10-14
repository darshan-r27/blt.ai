/// One chapter row of the Today card: chapter 1 or 2 of today (or up to the daily goal).
struct HomeTodayChapter: Equatable, Identifiable {
    let number: Int
    /// Finished today.
    let isDone: Bool
    /// The chapter the learner would start now: the first one not done, when there is something to practise.
    let isNext: Bool

    var id: Int { number }
}
