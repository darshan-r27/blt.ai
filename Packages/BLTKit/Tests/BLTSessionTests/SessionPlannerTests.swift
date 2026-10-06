import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

/// SplitMix64: a small deterministic generator so every planner test is reproducible.
private struct PlannerTestGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

struct SessionPlannerTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let planner = SessionPlanner()
    private let seeds = UInt64(1)...UInt64(20)

    private func item(_ number: Int) -> Item {
        Item(
            id: ItemID(rawValue: "zz-\(number)"),
            scenarioID: ScenarioID(rawValue: "zz-s"),
            sourcePrompt: "zz prompt \(number)",
            register: .neutral,
            addressee: .any,
            canonical: "zz canonical \(number)",
            acceptedAnswers: ["zz canonical \(number)", "zz b", "zz c"],
            registerVariant: nil,
            distractors: ["zz w1 \(number)", "zz w2 \(number)", "zz w3 \(number)"],
            tokens: [],
            note: nil,
            reviewStatus: .unreviewed
        )
    }

    private func scenario(count: Int) -> Scenario {
        Scenario(
            id: ScenarioID(rawValue: "zz-s"),
            title: "zz",
            subtitle: "zz",
            romanisationNote: nil,
            items: (0..<count).map { item($0 + 1) }
        )
    }

    private func review(_ number: Int, due: Date) -> ReviewState {
        ReviewState(
            itemID: ItemID(rawValue: "zz-\(number)"),
            repetitions: 1,
            intervalDays: 1,
            easeFactor: 2.5,
            due: due,
            lastOutcome: .correct,
            lastReviewed: now.addingTimeInterval(-86_400)
        )
    }

    private func snapshot(_ reviews: [ReviewState]) -> ProgressSnapshot {
        ProgressSnapshot(reviews: Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) }), attempts: [])
    }

    private func ids(_ items: [Item]) -> [String] {
        items.map(\.id.rawValue)
    }

    private func plan(
        _ scenario: Scenario,
        _ snapshot: ProgressSnapshot,
        seed: UInt64 = 1,
        limit: Int = 10
    ) -> [Item] {
        var rng = PlannerTestGenerator(seed: seed)
        return planner.plan(scenario: scenario, snapshot: snapshot, now: now, limit: limit, using: &rng)
    }

    private func reviewAnyway(
        _ scenario: Scenario,
        _ snapshot: ProgressSnapshot,
        seed: UInt64 = 1,
        limit: Int = 10
    ) -> [Item] {
        var rng = PlannerTestGenerator(seed: seed)
        return planner.reviewAnywayPlan(scenario: scenario, snapshot: snapshot, limit: limit, using: &rng)
    }

    @Test func freshScenarioPlansEveryItemOnceInSomeOrder() {
        let planned = plan(scenario(count: 4), .empty)
        #expect(Set(ids(planned)) == ["zz-1", "zz-2", "zz-3", "zz-4"])
        #expect(planned.count == 4)
    }

    @Test func allDueItemsAreSelectedBeforeAnyNewItem() {
        let reviews = [
            review(4, due: now.addingTimeInterval(-100)),
            review(2, due: now.addingTimeInterval(-500)),
            review(3, due: now)
        ]
        for seed in seeds {
            let planned = plan(scenario(count: 12), snapshot(reviews), seed: seed, limit: 5)
            #expect(Set(ids(planned)).isSuperset(of: ["zz-2", "zz-3", "zz-4"]))
            #expect(planned.count == 5)
        }
    }

    @Test func dueItemsWinWhenThereAreMoreOfThemThanTheLimit() {
        let reviews = (1...5).map { review($0, due: now.addingTimeInterval(Double(-$0 * 10))) }
        for seed in seeds {
            let planned = plan(scenario(count: 8), snapshot(reviews), seed: seed, limit: 3)
            #expect(Set(ids(planned)) == ["zz-3", "zz-4", "zz-5"])
        }
    }

    @Test func seenItemsThatAreNotDueAreExcluded() {
        let reviews = [review(1, due: now.addingTimeInterval(1)), review(2, due: now.addingTimeInterval(86_400))]
        for seed in seeds {
            #expect(ids(plan(scenario(count: 3), snapshot(reviews), seed: seed)) == ["zz-3"])
        }
    }

    @Test func newItemsAreARandomSampleOfTheUnseenOnes() {
        let reviews = [review(1, due: now.addingTimeInterval(-10))]
        let unseen = Set((2...15).map { "zz-\($0)" })
        var samples = Set<Set<String>>()
        for seed in seeds {
            let planned = plan(scenario(count: 15), snapshot(reviews), seed: seed, limit: 4)
            let newIDs = ids(planned).filter { $0 != "zz-1" }
            #expect(newIDs.count == 3)
            #expect(Set(newIDs).count == newIDs.count)
            #expect(Set(newIDs).isSubset(of: unseen))
            samples.insert(Set(newIDs))
        }
        #expect(samples.count > 1)
    }

    @Test func planNeverRepeatsAnItemOrExceedsTheLimit() {
        for seed in seeds {
            let planned = plan(scenario(count: 20), .empty, seed: seed)
            #expect(planned.count == 10)
            #expect(Set(ids(planned)).count == 10)
        }
    }

    @Test func finalOrderIsAPermutationOfTheSelection() {
        let reviews = [review(2, due: now.addingTimeInterval(-10))]
        let everything = ["zz-1", "zz-2", "zz-3", "zz-4", "zz-5", "zz-6"]
        var orders = Set<[String]>()
        for seed in seeds {
            let planned = ids(plan(scenario(count: 6), snapshot(reviews), seed: seed))
            #expect(planned.sorted() == everything)
            orders.insert(planned)
        }
        #expect(orders.count > 1)
    }

    @Test func dueAndNewItemsInterleave() {
        let reviews = [review(1, due: now.addingTimeInterval(-10))]
        let positions = seeds.map { seed in
            ids(plan(scenario(count: 10), snapshot(reviews), seed: seed)).firstIndex(of: "zz-1")
        }
        #expect(Set(positions).count > 1)
    }

    @Test func aFixedSeedReproducesThePlan() {
        let first = ids(plan(scenario(count: 20), .empty, seed: 99))
        let second = ids(plan(scenario(count: 20), .empty, seed: 99))
        #expect(first == second)
    }

    @Test func theFirstQuestionVariesAcrossSeeds() {
        let firsts = seeds.compactMap { seed in
            ids(plan(scenario(count: 20), .empty, seed: seed)).first
        }
        #expect(firsts.count == 20)
        #expect(Set(firsts).count > 1)
    }

    @Test func defaultLimitIsTenAndZeroMeansEmpty() {
        #expect(plan(scenario(count: 20), .empty).count == 10)
        #expect(plan(scenario(count: 20), .empty, limit: 0).isEmpty)
        #expect(plan(scenario(count: 20), .empty, limit: -3).isEmpty)
    }

    @Test func anEmptyScenarioPlansNothing() {
        let none = Scenario(
            id: ScenarioID(rawValue: "zz-s"),
            title: "zz",
            subtitle: "zz",
            romanisationNote: nil,
            items: []
        )
        #expect(plan(none, .empty).isEmpty)
        #expect(reviewAnyway(none, .empty).isEmpty)
    }

    @Test func reviewedForTheFutureMeansEmptyPlan() {
        let reviews = (1...3).map { review($0, due: now.addingTimeInterval(86_400)) }
        #expect(plan(scenario(count: 3), snapshot(reviews)).isEmpty)
    }

    @Test func reviewAnywaySelectsTheEarliestDueSeenItemsInRandomOrder() {
        let reviews = [
            review(1, due: now.addingTimeInterval(300)),
            review(2, due: now.addingTimeInterval(100)),
            review(4, due: now.addingTimeInterval(200)),
            review(5, due: now.addingTimeInterval(400))
        ]
        let snap = snapshot(reviews)
        var orders = Set<[String]>()
        for seed in seeds {
            let picked = reviewAnyway(scenario(count: 6), snap, seed: seed, limit: 3)
            #expect(Set(ids(picked)) == ["zz-2", "zz-4", "zz-1"])
            orders.insert(ids(picked))
        }
        #expect(orders.count > 1)
        let everything = reviewAnyway(scenario(count: 6), snap)
        #expect(Set(ids(everything)) == ["zz-1", "zz-2", "zz-4", "zz-5"])
    }

    @Test func reviewAnywayIsEmptyWithNothingSeen() {
        #expect(reviewAnyway(scenario(count: 3), .empty).isEmpty)
    }

    @Test func reviewStatesForOtherScenariosAreIgnored() {
        let stray = review(99, due: now.addingTimeInterval(-10))
        let planned = plan(scenario(count: 2), snapshot([stray]))
        #expect(Set(ids(planned)) == ["zz-1", "zz-2"])
        #expect(reviewAnyway(scenario(count: 2), snapshot([stray])).isEmpty)
    }
}
