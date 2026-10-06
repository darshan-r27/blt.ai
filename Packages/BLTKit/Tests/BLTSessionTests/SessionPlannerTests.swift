import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Testing

struct SessionPlannerTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let planner = SessionPlanner()

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
            items: (1...count).map(item)
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

    @Test func freshSnapshotPlansAllItemsInContentOrder() {
        let plan = planner.plan(scenario: scenario(count: 4), snapshot: .empty, now: now)
        #expect(ids(plan) == ["zz-1", "zz-2", "zz-3", "zz-4"])
    }

    @Test func dueItemsComeFirstEarliestDueFirstThenUnseen() {
        let reviews = [
            review(4, due: now.addingTimeInterval(-100)),
            review(2, due: now.addingTimeInterval(-500)),
            review(3, due: now)
        ]
        let plan = planner.plan(scenario: scenario(count: 5), snapshot: snapshot(reviews), now: now)
        #expect(ids(plan) == ["zz-2", "zz-4", "zz-3", "zz-1", "zz-5"])
    }

    @Test func seenItemsThatAreNotDueAreExcluded() {
        let reviews = [review(1, due: now.addingTimeInterval(1)), review(2, due: now.addingTimeInterval(86_400))]
        let plan = planner.plan(scenario: scenario(count: 3), snapshot: snapshot(reviews), now: now)
        #expect(ids(plan) == ["zz-3"])
    }

    @Test func equalDueDatesKeepContentOrder() {
        let reviews = [review(3, due: now), review(1, due: now), review(2, due: now)]
        let plan = planner.plan(scenario: scenario(count: 3), snapshot: snapshot(reviews), now: now)
        #expect(ids(plan) == ["zz-1", "zz-2", "zz-3"])
    }

    @Test func planIsCappedAtLimitWithDueItemsWinning() {
        let reviews = [review(5, due: now.addingTimeInterval(-10))]
        let plan = planner.plan(scenario: scenario(count: 8), snapshot: snapshot(reviews), now: now, limit: 3)
        #expect(ids(plan) == ["zz-5", "zz-1", "zz-2"])
    }

    @Test func defaultLimitIsTen() {
        let plan = planner.plan(scenario: scenario(count: 20), snapshot: .empty, now: now)
        #expect(plan.count == 10)
        #expect(planner.plan(scenario: scenario(count: 20), snapshot: .empty, now: now, limit: 0).isEmpty)
    }

    @Test func reviewedForTheFutureMeansEmptyPlan() {
        let reviews = (1...3).map { review($0, due: now.addingTimeInterval(86_400)) }
        let plan = planner.plan(scenario: scenario(count: 3), snapshot: snapshot(reviews), now: now)
        #expect(plan.isEmpty)
    }

    @Test func reviewAnywayPicksEarliestDueAmongSeenItemsOnly() {
        let reviews = [
            review(1, due: now.addingTimeInterval(300)),
            review(2, due: now.addingTimeInterval(100)),
            review(4, due: now.addingTimeInterval(200))
        ]
        let plan = planner.reviewAnywayPlan(scenario: scenario(count: 5), snapshot: snapshot(reviews), limit: 2)
        #expect(ids(plan) == ["zz-2", "zz-4"])
        let everything = planner.reviewAnywayPlan(scenario: scenario(count: 5), snapshot: snapshot(reviews))
        #expect(ids(everything) == ["zz-2", "zz-4", "zz-1"])
    }

    @Test func reviewAnywayIsEmptyWithNothingSeen() {
        #expect(planner.reviewAnywayPlan(scenario: scenario(count: 3), snapshot: .empty).isEmpty)
    }

    @Test func reviewStatesForOtherScenariosAreIgnored() {
        let stray = review(99, due: now.addingTimeInterval(-10))
        let plan = planner.plan(scenario: scenario(count: 2), snapshot: snapshot([stray]), now: now)
        #expect(ids(plan) == ["zz-1", "zz-2"])
        #expect(planner.reviewAnywayPlan(scenario: scenario(count: 2), snapshot: snapshot([stray])).isEmpty)
    }
}
