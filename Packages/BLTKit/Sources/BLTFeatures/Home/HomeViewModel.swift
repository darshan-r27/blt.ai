import BLTCatalog
import BLTCore
import BLTProgress
import Foundation
import Observation

/// Drives the Scenarios (home) screen.
///
/// A store error is shown, never repaired: nothing here resets, rewrites or deletes saved progress
/// unless the user goes through `requestReset()` and then `confirmReset()`.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var scenarios: [ScenarioSummary] = []
    /// Set when the store could not be read. While set, `scenarios` is empty.
    private(set) var loadError: ProgressStoreError?
    private(set) var hasLoaded = false
    /// Set when a reset was confirmed but the store could not erase.
    private(set) var resetError: ProgressStoreError?
    private(set) var isResetting = false
    /// Bound to the confirmation dialog. Setting it is not a confirmation; only `confirmReset()` erases.
    var isConfirmingReset = false

    /// Levels the learner has opened or closed by hand, keyed by level number. Not saved: a fresh launch goes
    /// back to the defaults (finished levels closed, the rest open).
    private var expansionOverrides: [Int: Bool] = [:]

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// The greeting above the scenario cards. `name` is the validated display name (DECISIONS 030).
    static func greeting(forName name: String) -> String {
        "Hi \(name)"
    }

    /// The calm line saying which course is being learned, or `nil` (nothing is shown) when no language is known.
    static func languageLine(for language: CourseLanguage?) -> String? {
        language.map { "Learning \($0.displayName)" }
    }

    /// Lessons that carry a level, grouped by level number in ascending order. Lessons inside a level are sorted
    /// by `level.position`, then by id. Nothing is locked: every lesson can be opened (DECISIONS 039).
    var levelSections: [HomeLevelSection] {
        let leveled = scenarios.compactMap { summary in summary.level.map { (summary, $0) } }
        return Dictionary(grouping: leveled, by: { $0.1.number })
            .map { number, members in
                let ordered = members.sorted {
                    ($0.1.position, $0.0.id.rawValue) < ($1.1.position, $1.0.id.rawValue)
                }
                return HomeLevelSection(number: number, title: ordered[0].1.title, lessons: ordered.map(\.0))
            }
            .sorted { $0.number < $1.number }
    }

    /// Lessons with no level (older imports), in catalog order.
    var otherLessons: [ScenarioSummary] {
        scenarios.filter { $0.level == nil }
    }

    /// The first lesson that is not fully complete: levels in order, lessons by position, then lessons with no
    /// level. `nil` when everything is complete or there is nothing to practise.
    var continueLesson: ScenarioSummary? {
        let ordered = levelSections.flatMap(\.lessons) + otherLessons
        return ordered.first { $0.totalCount > 0 && !$0.isComplete }
    }

    /// Whether a level's lessons are shown. Without a choice by the learner, finished levels are collapsed.
    func isExpanded(_ section: HomeLevelSection) -> Bool {
        expansionOverrides[section.number] ?? !section.isComplete
    }

    /// Opens a closed level or closes an open one.
    func toggle(_ section: HomeLevelSection) {
        expansionOverrides[section.number] = !isExpanded(section)
    }

    /// Only a damaged or newer-than-supported file can be fixed by erasing it. A transient read
    /// failure (`.unreadable`) should be retried instead, so no Reset is offered for it.
    var canOfferReset: Bool {
        switch loadError {
        case .corrupt, .unsupportedSchemaVersion: true
        default: false
        }
    }

    func load() async {
        do throws(ProgressStoreError) {
            let snapshot = try await dependencies.store.load()
            scenarios = dependencies.catalog.scenarios.map { ScenarioSummary(scenario: $0, snapshot: snapshot) }
            loadError = nil
        } catch {
            scenarios = []
            loadError = error
        }
        hasLoaded = true
    }

    /// Step one of Reset: ask the user. Erases nothing.
    func requestReset() {
        resetError = nil
        isConfirmingReset = true
    }

    func cancelReset() {
        isConfirmingReset = false
    }

    /// Step two of Reset: wired only to the dialog's destructive button. Erases the store, then
    /// reloads. If erasing fails the error is surfaced in `resetError` and the load error stays.
    func confirmReset() async {
        isConfirmingReset = false
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        do throws(ProgressStoreError) {
            try await dependencies.store.eraseAll()
        } catch {
            resetError = error
            return
        }
        resetError = nil
        await load()
    }
}
