import BLTCatalog
import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI

/// Home and everything reachable from it. Built only once there is a profile.
///
/// Home is reloaded when a session is dismissed and when Settings finishes a reset, so the cards
/// never show figures from before the last answer.
///
/// Daily practice (DECISIONS 047) is wired here: the flame chip opens the streak screen, a finished session
/// reloads Home and may offer the notification pre-prompt, and every moment that can change what is due
/// (a recorded session, a changed setting, Reset progress, launch, coming back to the foreground) reschedules
/// the reminders for this course.
struct HomeFlow: View {
    /// A pushed screen. Plain values so the stack's path stays `Hashable`.
    private enum Destination: Hashable {
        case progress
        case settings
    }

    /// The scenario whose session is on screen.
    private struct SessionSelection: Identifiable {
        let scenario: Scenario
        var id: ScenarioID { scenario.id }
    }

    private let dependencies: AppDependencies
    private let profileStore: any ProfileStore
    private let name: String
    private let onNameChanged: @MainActor (UserProfile) -> Void
    private let onLanguageChanged: @MainActor (UserProfile) -> Void
    private let lessonImporter: (any LessonImporting)?
    private let onLessonsChanged: @MainActor (LessonChange) -> Void
    private let practice: PracticeServices
    /// One set of streak rules for Home, the session end and the streak screen, so they always agree.
    private let streakCalculator = StreakCalculator()
    private let rescheduler: ReminderRescheduler
    @Environment(\.scenePhase) private var scenePhase
    @State private var home: HomeViewModel
    @State private var path: [Destination] = []
    @State private var session: SessionSelection?
    @State private var isTakingExam = false
    @State private var isShowingStreak = false
    @State private var cheatSheet: CheatSheetViewModel?
    @State private var isShowingCheatSheetList = false
    @State private var notificationsPrompt: NotificationsPromptViewModel?

    init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        name: String,
        onNameChanged: @escaping @MainActor (UserProfile) -> Void,
        onLanguageChanged: @escaping @MainActor (UserProfile) -> Void,
        lessonImporter: (any LessonImporting)?,
        onLessonsChanged: @escaping @MainActor (LessonChange) -> Void,
        practice: PracticeServices
    ) {
        self.dependencies = dependencies
        self.profileStore = profileStore
        self.name = name
        self.onNameChanged = onNameChanged
        self.onLanguageChanged = onLanguageChanged
        self.lessonImporter = lessonImporter
        self.onLessonsChanged = onLessonsChanged
        self.practice = practice
        rescheduler = ReminderRescheduler(
            language: dependencies.language,
            log: dependencies.practiceLog,
            preferences: practice.preferences,
            reminders: practice.reminders,
            calculator: streakCalculator,
            now: dependencies.now,
            calendar: { Calendar.current }
        )
        _home = State(initialValue: HomeViewModel(
            dependencies: dependencies,
            practiceLog: dependencies.practiceLog,
            streakCalculator: streakCalculator,
            cheatSheetUnlocks: dependencies.cheatSheetUnlocks
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScenariosView(
                viewModel: home,
                name: name,
                language: dependencies.language,
                onSelectScenario: select,
                onOpenProgress: { path.append(.progress) },
                onOpenSettings: { path.append(.settings) },
                onOpenExam: { isTakingExam = true },
                onOpenStreak: { isShowingStreak = true },
                onOpenCheatSheet: openCheatSheet,
                onOpenCheatSheetList: { isShowingCheatSheetList = true }
            )
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .progress:
                    ProgressDestination(dependencies: dependencies)
                case .settings:
                    settingsDestination
                }
            }
            .sheet(item: promptBinding) { prompt in
                NotificationsPromptView(viewModel: prompt)
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(isPresented: $isTakingExam, onDismiss: reloadHome) {
            if let paper = dependencies.examPaper {
                ExamView(
                    viewModel: ExamViewModel(
                        paper: paper,
                        language: dependencies.language,
                        results: dependencies.examResults,
                        now: dependencies.now
                    ),
                    onDone: { isTakingExam = false }
                )
                .bltScreenBackground()
            }
        }
        .fullScreenCover(isPresented: $isShowingStreak) {
            StreakView(
                viewModel: StreakViewModel(
                    practiceLog: dependencies.practiceLog,
                    now: dependencies.now,
                    dailyGoal: streakCalculator.dailyGoal
                ),
                onDone: { isShowingStreak = false }
            )
            .bltScreenBackground()
        }
        .fullScreenCover(item: $cheatSheet) { sheet in
            CheatSheetView(viewModel: sheet, onClose: { cheatSheet = nil })
        }
        .fullScreenCover(isPresented: $isShowingCheatSheetList) {
            CheatSheetListView(
                viewModel: CheatSheetListViewModel(
                    scenarios: dependencies.catalog.scenarios,
                    unlockedTopicIDs: Set(home.unlockedCheatSheetIDs.map { ScenarioID(rawValue: $0) })
                ),
                onClose: { isShowingCheatSheetList = false }
            )
        }
        .fullScreenCover(item: $session, onDismiss: sessionDidEnd) { selection in
            SessionView(viewModel: sessionViewModel(for: selection.scenario), onDone: { session = nil })
                .bltScreenBackground()
        }
        // At launch, and again whenever the app comes back to the foreground (the streak may have lapsed, or the
        // learner may have changed notification settings in iOS Settings meanwhile).
        .task { await rescheduler.reschedule() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appDidBecomeActive() }
        }
    }

    private var settingsDestination: some View {
        SettingsDestination(
            dependencies: dependencies,
            profileStore: profileStore,
            name: name,
            onDidReset: resetDidFinish,
            onDidChangeName: onNameChanged,
            onDidChangeLanguage: onLanguageChanged,
            lessonImporter: lessonImporter,
            onDidChangeLessons: onLessonsChanged,
            practice: practice,
            onPracticeSettingsChanged: { [rescheduler] in await rescheduler.reschedule() }
        )
    }

    private func sessionViewModel(for scenario: Scenario) -> SessionViewModel {
        SessionViewModel(
            scenario: scenario,
            dependencies: dependencies,
            practiceLog: dependencies.practiceLog,
            streakCalculator: streakCalculator,
            onSessionRecorded: { [rescheduler] _ in await rescheduler.reschedule() }
        )
    }

    private func select(_ id: ScenarioID) {
        // An ID that is not in the catalog cannot come from a card, which is built from the same catalog.
        guard let scenario = dependencies.catalog.scenarios.first(where: { $0.id == id }) else { return }
        session = SessionSelection(scenario: scenario)
    }

    /// The "Cheat sheet" button on a finished topic's card. Only unlocked topics have the button, so a topic
    /// that is not in the catalog cannot arrive here.
    private func openCheatSheet(_ id: ScenarioID) {
        guard let scenario = dependencies.catalog.scenarios.first(where: { $0.id == id }) else { return }
        cheatSheet = CheatSheetViewModel(scenario: scenario)
    }

    private func reloadHome() {
        Task { await home.load() }
    }

    /// Reset progress cleared this course's log, so no reminder is due any more: the reschedule cancels them.
    private func resetDidFinish() {
        Task {
            await home.load()
            await rescheduler.reschedule()
        }
    }

    private func appDidBecomeActive() {
        Task {
            await home.loadPractice()
            await rescheduler.reschedule()
        }
    }

    /// A session cover closed: refresh Home, then offer the notification question if this was the very first
    /// finished session (the session has been recorded by now: leaving waits for it).
    private func sessionDidEnd() {
        reloadHome()
        Task {
            notificationsPrompt = await practice.notificationsPromptIfDue(
                onPracticeSettingsChanged: { [rescheduler] in await rescheduler.reschedule() },
                onFinished: { notificationsPrompt = nil }
            )
        }
    }

    /// Swiping the sheet away counts as Not now.
    private var promptBinding: Binding<NotificationsPromptViewModel?> {
        Binding(
            get: { notificationsPrompt },
            set: { newValue in
                if newValue == nil, let open = notificationsPrompt {
                    Task { await open.dismissed() }
                }
            }
        )
    }
}
