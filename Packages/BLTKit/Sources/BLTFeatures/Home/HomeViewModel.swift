import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
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

    /// The best stored exam attempt, or `nil` when there is none or it could not be read.
    private(set) var bestExamAttempt: ExamAttempt?
    /// Set when the stored exam results could not be read. Home still works; the exam entry says so.
    private(set) var examHistoryUnreadable = false

    /// The streak, freezes and today's chapters, computed from the practice log. The empty summary while the
    /// log has not been read or could not be (see `practiceError`).
    private(set) var practiceSummary: StreakSummary = .empty()
    /// Set when the practice log could not be read. Home and the scenarios still work; the practice section says
    /// so calmly. The file is never rewritten or erased because of it (only Reset erases).
    private(set) var practiceError: PracticeLogError?

    /// The topics whose cheat sheet is open: every topic ever recorded as complete, plus every topic complete
    /// right now (so one that has not been written down yet already shows its button). A topic that later slips
    /// below 100% stays in the stored part, so it keeps its button.
    private(set) var unlockedCheatSheetIDs: Set<String> = []
    /// Set when the unlock record could not be read or written. Home still works; topics that are complete right
    /// now still show their button, and the record is never rewritten or erased because of it (only Reset erases).
    private(set) var cheatSheetUnlockError: CheatSheetUnlockError?

    private let dependencies: AppDependencies
    private let practiceLog: any PracticeLogStore
    private let cheatSheetUnlocks: any CheatSheetUnlockStore
    /// The calendar that decides which dates "today" and "this week" are.
    let practiceCalendar: Calendar
    private let streakCalculator: StreakCalculator

    /// - Parameters:
    ///   - practiceLog: this course's practice log. The default is an empty in-memory log for previews and
    ///     tests only; the composition root passes the course's real store.
    ///   - calendar: decides which dates "today" and "this week" are; carries the learner's time zone.
    ///   - streakCalculator: the streak rules, with the daily goal.
    ///   - cheatSheetUnlocks: this course's record of topics whose cheat sheet is unlocked. The default is an
    ///     empty in-memory record for previews and tests only; the composition root passes the course's real store.
    init(
        dependencies: AppDependencies,
        practiceLog: any PracticeLogStore = InMemoryPracticeLogStore(),
        calendar: Calendar = .current,
        streakCalculator: StreakCalculator = StreakCalculator(),
        cheatSheetUnlocks: any CheatSheetUnlockStore = InMemoryCheatSheetUnlockStore()
    ) {
        self.dependencies = dependencies
        self.practiceLog = practiceLog
        self.practiceCalendar = calendar
        self.streakCalculator = streakCalculator
        self.cheatSheetUnlocks = cheatSheetUnlocks
    }

    /// The current time from the injected clock (the same one the streak is computed at).
    var currentTime: Date {
        dependencies.now()
    }

    /// The greeting above the scenario cards. `name` is the validated display name (DECISIONS 030).
    static func greeting(forName name: String) -> String {
        "Hi \(name)"
    }

    /// The calm line saying which course is being learned, or `nil` (nothing is shown) when no language is known.
    static func languageLine(for language: CourseLanguage?) -> String? {
        language.map { "Learning \($0.displayName)" }
    }

    /// What Home says when the catalog has no lessons. A named language gets a plain, specific line (a course
    /// with no lessons yet is normal while its content is being written); with none the line stays general.
    static func emptyStateCopy(for language: CourseLanguage?) -> (title: String, description: String) {
        guard let language else {
            return ("No scenarios", "This copy of the app has no lesson content to show.")
        }
        return (
            "No \(language.displayName) lessons yet",
            "There are no \(language.displayName) lessons in this copy of the app yet. "
                + "They will appear here once they are added."
        )
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

    /// The final-exam entry, or `nil` when this course has no exam paper yet (DECISIONS 041). It is open only when
    /// every level is complete; until then it is shown as locked, with the reason.
    var examEntry: ExamEntry? {
        guard let paper = dependencies.examPaper, paper.total > 0 else { return nil }
        let sections = levelSections
        let everyLevelComplete = !sections.isEmpty && sections.allSatisfy(\.isComplete)
        return ExamEntry(
            isUnlocked: everyLevelComplete,
            total: paper.total,
            passMarkPercent: ExamPaper.passMarkPercent,
            best: bestExamAttempt,
            historyUnreadable: examHistoryUnreadable
        )
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
        await loadExamHistory()
        await loadPractice()
        await recordCheatSheetUnlocks()
        hasLoaded = true
    }

    /// Reads the practice log and recomputes the streak at the current time. A read error is kept in
    /// `practiceError` and shown calmly; it never stops Home and never writes to the log. Call it again after
    /// a session finishes so the chip, the Today card and the week strip catch up.
    func loadPractice() async {
        do throws(PracticeLogError) {
            let log = try await practiceLog.load()
            practiceSummary = streakCalculator.summary(for: log, now: dependencies.now(), calendar: practiceCalendar)
            practiceError = nil
        } catch {
            practiceSummary = .empty(dailyGoal: streakCalculator.dailyGoal)
            practiceError = error
        }
    }

    /// Reads the best exam attempt. A failure is shown on the exam entry, never hidden, and does not stop Home.
    private func loadExamHistory() async {
        guard dependencies.examPaper != nil else { return }
        do throws(ExamResultStoreError) {
            bestExamAttempt = try await dependencies.examResults.bestAttempt()
            examHistoryUnreadable = false
        } catch {
            bestExamAttempt = nil
            examHistoryUnreadable = true
        }
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
        // Exam attempts belong to the same course, so Reset clears them too (DECISIONS 041).
        do throws(ExamResultStoreError) {
            try await dependencies.examResults.erase()
        } catch {
            resetError = .eraseFailed
            return
        }
        // The practice log (streak, freezes, goal days) belongs to the same course, so Reset clears it too.
        do throws(PracticeLogError) {
            try await practiceLog.erase()
        } catch {
            resetError = .eraseFailed
            return
        }
        // So does the cheat sheet record: a sheet belongs to a topic the learner has finished.
        do throws(CheatSheetUnlockError) {
            try await cheatSheetUnlocks.erase()
        } catch {
            resetError = .eraseFailed
            return
        }
        resetError = nil
        await load()
    }

    /// Writes down every topic that is complete now (DECISIONS 033 rule), then sets `unlockedCheatSheetIDs` to
    /// the written-down topics plus the complete ones. Topics finished before cheat sheets existed are caught
    /// here on the first load. A read or write failure is kept in `cheatSheetUnlockError`, never repaired.
    private func recordCheatSheetUnlocks() async {
        let completeNow = Set(scenarios.filter(\.isComplete).map(\.id.rawValue))
        var stored: Set<String> = []
        do throws(CheatSheetUnlockError) {
            stored = try await cheatSheetUnlocks.load()
            try await cheatSheetUnlocks.add(completeNow)
            cheatSheetUnlockError = nil
        } catch {
            cheatSheetUnlockError = error
        }
        unlockedCheatSheetIDs = stored.union(completeNow)
    }

    /// Whether this topic's cheat sheet is open, so its card shows the "Cheat sheet" button.
    func isCheatSheetUnlocked(_ id: ScenarioID) -> Bool {
        unlockedCheatSheetIDs.contains(id.rawValue)
    }
}
