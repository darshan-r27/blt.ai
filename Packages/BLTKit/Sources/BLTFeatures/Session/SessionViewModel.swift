import BLTCatalog
import BLTCore
import BLTProgress
import BLTSession
import Foundation
import Observation

/// Drives one study session for one scenario: loads progress, plans, runs a `SessionMachine`,
/// and records the first attempt at each item through the injected `ProgressStore`.
///
/// Randomness comes from an injected `SessionRandomSource` (`.system` in production, `.seeded`
/// in tests and previews), so option order is reproducible under test.
///
/// Persistence never blocks the learner: `choose` updates the machine immediately and queues the
/// write. Writes run one after another in order. If a write throws, `saveFailed` is set and
/// stays set for the rest of the session; the next question is never held up.
///
/// Pronunciation does not exist in v1 and nothing here reads it (CLAUDE.md constraint 5).
@MainActor
@Observable
final class SessionViewModel {
    /// What the session view should show right now.
    enum Screen: Equatable {
        case loading
        /// The progress file could not be read. The session does not start on an empty guess.
        case loadFailed
        /// Nothing is due and nothing is new, but earlier items exist: offer `startReviewAnyway()`.
        case nothingDue
        /// The scenario has nothing to study at all.
        case nothingToStudy
        case session(SessionState)
    }

    static let saveFailedMessage = "Your progress could not be saved. You can keep going."

    let scenario: Scenario

    /// True once any save has failed. Visible, non-blocking, never cleared during a session.
    private(set) var saveFailed = false

    /// Bumps on every screen change; the view keys its crossfade on it.
    private(set) var beat = 0

    /// True from the moment `endSession()` is first called. Once set, the session accepts no
    /// further answers, so nothing new can be written after the learner has left.
    private(set) var hasEnded = false

    private enum Phase {
        case loading
        case loadFailed
        case nothingDue
        case nothingToStudy
        case running
    }

    private let dependencies: AppDependencies
    private let planner = SessionPlanner()
    private var random: SessionRandomSource
    private var phase = Phase.loading
    private var machine: SessionMachine?
    private var snapshot = ProgressSnapshot.empty
    private var reviewAnywayItems: [Item] = []
    private var plannedOrder: [ItemID] = []
    private var wrongCounts: [ItemID: Int] = [:]
    private var hasStarted = false
    private var saveTask: Task<Void, Never>?
    private var doneHandler: (@MainActor () -> Void)?

    /// How many wrong answers an item can get before the machine stops requeuing it
    /// (it requeues at most twice, so the third wrong answer is the last).
    private static let wrongAnswersBeforeNoRequeue = 3

    init(
        scenario: Scenario,
        dependencies: AppDependencies,
        random: SessionRandomSource = .system
    ) {
        self.scenario = scenario
        self.dependencies = dependencies
        self.random = random
    }

    // MARK: Reading state

    var screen: Screen {
        switch phase {
        case .loading: .loading
        case .loadFailed: .loadFailed
        case .nothingDue: .nothingDue
        case .nothingToStudy: .nothingToStudy
        case .running:
            if let state = machine?.state { .session(state) } else { .nothingToStudy }
        }
    }

    /// 1-based position of the current item in the plan, counting each item once. A requeued
    /// item keeps its original number.
    var currentPosition: Int? {
        guard let id = currentItemID, let index = plannedOrder.firstIndex(of: id) else { return nil }
        return index + 1
    }

    /// Number of distinct items in this session.
    var plannedCount: Int { plannedOrder.count }

    /// Whether the item in the current feedback will be asked again this session.
    var currentItemWillReturn: Bool {
        guard let id = currentItemID else { return false }
        return wrongCounts[id, default: 0] < Self.wrongAnswersBeforeNoRequeue
    }

    // MARK: Actions

    /// Loads progress and plans the session. Safe to call again (for example from `.task`); only
    /// the first call does anything. Use `retry()` after a load failure.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await load()
    }

    func retry() async {
        guard !hasEnded else { return }
        setPhase(.loading)
        await load()
    }

    /// Starts a session from the earliest-due items when nothing was due or new.
    func startReviewAnyway() {
        guard phase == .nothingDue, !hasEnded else { return }
        begin(with: reviewAnywayItems)
    }

    /// Answers the current question. Only the first presentation of an item yields an
    /// `AttemptRecord`, so a requeued presentation schedules and writes nothing.
    func choose(_ optionID: Int) {
        guard !hasEnded, var current = machine else { return }
        let before = current.state
        var rng = random
        let attempt = current.choose(optionID, at: dependencies.now(), using: &rng)
        random = rng
        machine = current
        guard current.state != before else { return }
        beat += 1

        if case .feedback(let question, _, .notQuite) = current.state {
            wrongCounts[question.item.id, default: 0] += 1
        }
        if let attempt {
            persist(attempt)
        }
    }

    /// Moves from feedback to the next question, or to the summary.
    func advance() {
        guard !hasEnded, var current = machine else { return }
        let before = current.state
        var rng = random
        current.advance(using: &rng)
        random = rng
        machine = current
        if current.state != before {
            beat += 1
        }
    }

    /// Registers the closure `endSession()` calls to leave the session. The view sets this from
    /// its `onDone`. It is called at most once.
    func setDoneHandler(_ handler: @escaping @MainActor () -> Void) {
        doneHandler = handler
    }

    /// Leaves the session. First waits for every queued save, so each answer given so far is
    /// persisted, then calls the done handler exactly once. The unanswered current item records
    /// nothing, and after the first call the session ignores answers, so repeated calls (a
    /// double tap) do nothing.
    func endSession() async {
        guard !hasEnded else { return }
        hasEnded = true
        await waitForPendingSaves()
        let handler = doneHandler
        doneHandler = nil
        handler?()
    }

    /// Waits until every queued save has finished. For tests, and for a host that wants to be
    /// sure nothing is in flight before it tears the session down.
    func waitForPendingSaves() async {
        await saveTask?.value
    }

    // MARK: Private

    private var currentItemID: ItemID? {
        switch machine?.state {
        case .asking(let question), .feedback(let question, _, _): question.item.id
        case .finished, nil: nil
        }
    }

    private func load() async {
        do {
            snapshot = try await dependencies.store.load()
        } catch {
            setPhase(.loadFailed)
            return
        }
        guard !hasEnded else { return }
        let now = dependencies.now()
        var rng = random
        let planned = planner.plan(scenario: scenario, snapshot: snapshot, now: now, using: &rng)
        random = rng
        if !planned.isEmpty {
            begin(with: planned)
            return
        }
        reviewAnywayItems = planner.reviewAnywayPlan(scenario: scenario, snapshot: snapshot, using: &rng)
        random = rng
        setPhase(reviewAnywayItems.isEmpty ? .nothingToStudy : .nothingDue)
    }

    private func begin(with items: [Item]) {
        var rng = random
        let started = SessionMachine(items: items, using: &rng)
        random = rng
        if case .finished = started.state {
            // No item could be turned into a four-option question; there is nothing to ask.
            machine = nil
            setPhase(.nothingToStudy)
            return
        }
        machine = started
        plannedOrder = items.map(\.id)
        wrongCounts = [:]
        setPhase(.running)
    }

    private func setPhase(_ newPhase: Phase) {
        phase = newPhase
        beat += 1
    }

    private func persist(_ attempt: AttemptRecord) {
        let review = dependencies.scheduler.review(
            snapshot.reviews[attempt.itemID],
            itemID: attempt.itemID,
            outcome: attempt.outcome,
            at: attempt.date
        )
        snapshot.reviews[attempt.itemID] = review
        snapshot.attempts.append(attempt)

        let store = dependencies.store
        let previousSave = saveTask
        saveTask = Task { [weak self] in
            await previousSave?.value
            do {
                try await store.record(attempt, updating: review)
            } catch {
                self?.saveFailed = true
            }
        }
    }
}
