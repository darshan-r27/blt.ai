#if DEBUG
import BLTCore
import BLTProgress
import Foundation

/// Fake dependencies for the previews of Home, Progress and Settings. Built only from `PreviewCatalog`.
enum PreviewDependencies {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func make(store: any ProgressStore) -> AppDependencies {
        AppDependencies(
            catalog: PreviewCatalog.catalog,
            store: store,
            scheduler: SM2Scheduler(),
            now: { now }
        )
    }

    static func withData() -> AppDependencies {
        make(store: InMemoryProgressStore(initial: snapshot))
    }

    /// The leveled catalog: level 1 finished, level 2 started, one lesson with no level.
    static func withLevels() -> AppDependencies {
        AppDependencies(
            catalog: PreviewCatalog.leveledCatalog,
            store: InMemoryProgressStore(initial: leveledSnapshot),
            scheduler: SM2Scheduler(),
            now: { now }
        )
    }

    static func empty() -> AppDependencies {
        make(store: InMemoryProgressStore())
    }

    static func failing(_ error: ProgressStoreError) -> AppDependencies {
        make(store: PreviewFailingStore(loadError: error))
    }

    /// One due item (respectful, with a register variant) and one learned item (neutral).
    static var snapshot: ProgressSnapshot {
        let first = PreviewCatalog.respectfulItem.id
        let second = PreviewCatalog.neutralItem.id
        let day: TimeInterval = 86_400
        let reviews = [
            ReviewState(
                itemID: first,
                repetitions: 1,
                intervalDays: 1,
                easeFactor: 2.5,
                due: now.addingTimeInterval(-day),
                lastOutcome: .wrongRegister,
                lastReviewed: now.addingTimeInterval(-2 * day)
            ),
            ReviewState(
                itemID: second,
                repetitions: 3,
                intervalDays: 16,
                easeFactor: 2.6,
                due: now.addingTimeInterval(10 * day),
                lastOutcome: .correct,
                lastReviewed: now.addingTimeInterval(-6 * day)
            )
        ]
        let attempts = [
            AttemptRecord(itemID: first, outcome: .correct, date: now.addingTimeInterval(-4 * day)),
            AttemptRecord(itemID: first, outcome: .wrongRegister, date: now.addingTimeInterval(-2 * day)),
            AttemptRecord(itemID: second, outcome: .correct, date: now.addingTimeInterval(-6 * day))
        ]
        let byID = Dictionary(uniqueKeysWithValues: reviews.map { ($0.itemID, $0) })
        return ProgressSnapshot(reviews: byID, attempts: attempts)
    }

    /// Every item of both level 1 lessons correct; two of the four items of "zz-l2-a" correct.
    static var leveledSnapshot: ProgressSnapshot {
        let day: TimeInterval = 86_400
        let correct = (
            ["zz-l1-a", "zz-l1-b"].flatMap { lesson in (1...4).map { "\(lesson)-i\($0)" } }
                + ["zz-l2-a-i1", "zz-l2-a-i2"]
        ).map { id in
            ReviewState(
                itemID: ItemID(rawValue: id),
                repetitions: 1,
                intervalDays: 1,
                easeFactor: 2.5,
                due: now.addingTimeInterval(day),
                lastOutcome: .correct,
                lastReviewed: now.addingTimeInterval(-day)
            )
        }
        return ProgressSnapshot(
            reviews: Dictionary(uniqueKeysWithValues: correct.map { ($0.itemID, $0) }),
            attempts: []
        )
    }
}
#endif
