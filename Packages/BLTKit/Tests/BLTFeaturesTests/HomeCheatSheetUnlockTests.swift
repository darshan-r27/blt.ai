import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Testing

@testable import BLTFeatures

// Home records finished topics for the cheat sheet list and opens their button. Fake `zz` text only.

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func state(_ item: Item, outcome: Outcome) -> ReviewState {
    ReviewState(
        itemID: item.id,
        repetitions: 1,
        intervalDays: 1,
        easeFactor: 2.5,
        due: now,
        lastOutcome: outcome,
        lastReviewed: now
    )
}

private func snapshot(_ lessons: [Scenario], outcome: Outcome = .correct) -> ProgressSnapshot {
    let states = lessons.flatMap(\.items).map { state($0, outcome: outcome) }
    return ProgressSnapshot(reviews: Dictionary(uniqueKeysWithValues: states.map { ($0.itemID, $0) }), attempts: [])
}

private let lessonA = PreviewCatalog.lesson("zz-a", title: "zz Lesson A", level: nil)
private let lessonB = PreviewCatalog.lesson("zz-b", title: "zz Lesson B", level: nil)

@MainActor
private func makeModel(
    progress: any ProgressStore,
    unlocks: any CheatSheetUnlockStore
) -> HomeViewModel {
    HomeViewModel(
        dependencies: AppDependencies(
            catalog: Catalog(scenarios: [lessonA, lessonB], issues: []),
            language: .tamil,
            store: progress,
            scheduler: SM2Scheduler(),
            now: { now }
        ),
        cheatSheetUnlocks: unlocks
    )
}

@MainActor
struct HomeCheatSheetUnlockTests {
    @Test func aTopicUnlocksTheFirstTimeItIsComplete() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore()
        let model = makeModel(progress: InMemoryProgressStore(initial: snapshot([lessonA])), unlocks: unlocks)
        await model.load()
        #expect(model.isCheatSheetUnlocked(lessonA.id))
        #expect(model.isCheatSheetUnlocked(lessonB.id) == false)
        #expect(try await unlocks.load() == ["zz-a"])
        #expect(model.cheatSheetUnlockError == nil)
    }

    @Test func aTopicInProgressOrNeverStartedIsNotUnlocked() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore()
        let started = InMemoryProgressStore(initial: snapshot([lessonA], outcome: .wrong))
        let model = makeModel(progress: started, unlocks: unlocks)
        await model.load()
        #expect(model.unlockedCheatSheetIDs.isEmpty)
        #expect(try await unlocks.load().isEmpty)
    }

    @Test func aTopicKeepsItsButtonAfterItSlipsBelowOneHundredPercent() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore()
        let progress = InMemoryProgressStore(initial: snapshot([lessonA]))
        let model = makeModel(progress: progress, unlocks: unlocks)
        await model.load()
        #expect(model.isCheatSheetUnlocked(lessonA.id))

        let slipped = try #require(lessonA.items.first)
        let attempt = AttemptRecord(itemID: slipped.id, outcome: .wrong, date: now)
        try await progress.record(attempt, updating: state(slipped, outcome: .wrong))
        await model.load()

        let summary = try #require(model.scenarios.first { $0.id == lessonA.id })
        #expect(summary.isComplete == false)
        #expect(model.isCheatSheetUnlocked(lessonA.id))
        #expect(try await unlocks.load() == ["zz-a"])
    }

    @Test func topicsCompletedBeforeTheFeatureUnlockOnTheFirstLoad() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore()
        let finished = InMemoryProgressStore(initial: snapshot([lessonA, lessonB]))
        let model = makeModel(progress: finished, unlocks: unlocks)
        #expect(try await unlocks.load().isEmpty)
        await model.load()
        #expect(model.unlockedCheatSheetIDs == ["zz-a", "zz-b"])
        #expect(try await unlocks.load() == ["zz-a", "zz-b"])
    }

    @Test func aStoredUnlockShowsEvenWhenNothingIsCompleteNow() async {
        let unlocks = InMemoryCheatSheetUnlockStore(initial: ["zz-b"])
        let model = makeModel(progress: InMemoryProgressStore(), unlocks: unlocks)
        await model.load()
        #expect(model.isCheatSheetUnlocked(lessonB.id))
        #expect(model.isCheatSheetUnlocked(lessonA.id) == false)
    }

    @Test func resetClearsTheUnlockRecordAndTheButtons() async throws {
        let unlocks = InMemoryCheatSheetUnlockStore()
        let model = makeModel(progress: InMemoryProgressStore(initial: snapshot([lessonA])), unlocks: unlocks)
        await model.load()
        #expect(model.isCheatSheetUnlocked(lessonA.id))

        await model.confirmReset()
        #expect(model.resetError == nil)
        #expect(try await unlocks.load().isEmpty)
        #expect(model.unlockedCheatSheetIDs.isEmpty)
    }

    @Test func homeWorksWithoutAnUnlockStoreArgument() async {
        let model = HomeViewModel(dependencies: AppDependencies(
            catalog: Catalog(scenarios: [lessonA], issues: []),
            language: .tamil,
            store: InMemoryProgressStore(initial: snapshot([lessonA])),
            scheduler: SM2Scheduler(),
            now: { now }
        ))
        await model.load()
        #expect(model.isCheatSheetUnlocked(lessonA.id))
    }
}
