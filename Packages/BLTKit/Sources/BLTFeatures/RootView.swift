import BLTCatalog
import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI

/// The app's front door and navigation.
///
/// It first loads the saved profile (DECISIONS 030). With none, the person sees the intro and name entry
/// once; with one, Home opens straight away; a profile that cannot be read gets a calm explanation
/// instead of being silently replaced. Home then works as before: Scenarios is home, Progress and
/// Settings push onto its stack, and a session covers the whole screen.
///
/// `AppDependencies` is deliberately unchanged, so the profile store arrives as its own parameter.
public struct RootView: View {
    private let dependencies: AppDependencies
    private let profileStore: any ProfileStore
    private let lessonImporter: (any LessonImporting)?
    private let onLessonsChanged: @MainActor (LessonChange) -> Void
    @State private var gate: ProfileGateViewModel

    /// `lessonImporter` turns on the Lessons section in Settings. After an import or a removal,
    /// `onLessonsChanged` tells the owner of the catalog to load it again and build a new root.
    public init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        lessonImporter: (any LessonImporting)? = nil,
        onLessonsChanged: @escaping @MainActor (LessonChange) -> Void = { _ in }
    ) {
        self.dependencies = dependencies
        self.profileStore = profileStore
        self.lessonImporter = lessonImporter
        self.onLessonsChanged = onLessonsChanged
        _gate = State(initialValue: ProfileGateViewModel(store: profileStore))
    }

    public var body: some View {
        content
            // Once, at the root: the purple accent reaches toolbar icons, links, cursors, sheets and the session cover.
            .bltTheme()
            .task { await gate.load() }
    }

    @ViewBuilder private var content: some View {
        switch gate.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .bltScreenBackground()
        case .needsOnboarding:
            OnboardingFlow(gate: gate)
        case .needsLanguage(let profile):
            LanguageChoiceView(gate: gate, profile: profile)
        case .loadFailed(let error):
            ProfileLoadProblemView(gate: gate, error: error)
        case .ready(let profile):
            HomeFlow(
                dependencies: dependencies,
                profileStore: profileStore,
                name: profile.name,
                onNameChanged: { gate.profileDidChange($0) },
                lessonImporter: lessonImporter,
                onLessonsChanged: onLessonsChanged
            )
        }
    }
}

/// Home and everything reachable from it. Built only once there is a profile.
///
/// Home is reloaded when a session is dismissed and when Settings finishes a reset, so the cards
/// never show figures from before the last answer.
private struct HomeFlow: View {
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
    private let lessonImporter: (any LessonImporting)?
    private let onLessonsChanged: @MainActor (LessonChange) -> Void
    @State private var home: HomeViewModel
    @State private var path: [Destination] = []
    @State private var session: SessionSelection?

    init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        name: String,
        onNameChanged: @escaping @MainActor (UserProfile) -> Void,
        lessonImporter: (any LessonImporting)?,
        onLessonsChanged: @escaping @MainActor (LessonChange) -> Void
    ) {
        self.dependencies = dependencies
        self.profileStore = profileStore
        self.name = name
        self.onNameChanged = onNameChanged
        self.lessonImporter = lessonImporter
        self.onLessonsChanged = onLessonsChanged
        _home = State(initialValue: HomeViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScenariosView(
                viewModel: home,
                name: name,
                onSelectScenario: select,
                onOpenProgress: { path.append(.progress) },
                onOpenSettings: { path.append(.settings) }
            )
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .progress:
                    ProgressDestination(dependencies: dependencies)
                case .settings:
                    SettingsDestination(
                        dependencies: dependencies,
                        profileStore: profileStore,
                        name: name,
                        onDidReset: reloadHome,
                        onDidChangeName: onNameChanged,
                        lessonImporter: lessonImporter,
                        onDidChangeLessons: onLessonsChanged
                    )
                }
            }
        }
        .fullScreenCover(item: $session, onDismiss: reloadHome) { selection in
            SessionView(
                viewModel: SessionViewModel(scenario: selection.scenario, dependencies: dependencies),
                onDone: { session = nil }
            )
            .bltScreenBackground()
        }
    }

    private func select(_ id: ScenarioID) {
        // An ID that is not in the catalog cannot come from a card, which is built from the same catalog.
        guard let scenario = dependencies.catalog.scenarios.first(where: { $0.id == id }) else { return }
        session = SessionSelection(scenario: scenario)
    }

    private func reloadHome() {
        Task { await home.load() }
    }
}

/// Owns the Progress view model so it lives as long as the pushed screen does.
private struct ProgressDestination: View {
    @State private var viewModel: ProgressViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: ProgressViewModel(dependencies: dependencies))
    }

    var body: some View {
        ProgressScreen(viewModel: viewModel)
    }
}

/// Owns the Settings view model, so a fresh visit starts without the last visit's reset message.
private struct SettingsDestination: View {
    @State private var viewModel: SettingsViewModel

    init(
        dependencies: AppDependencies,
        profileStore: any ProfileStore,
        name: String,
        onDidReset: @escaping @MainActor () -> Void,
        onDidChangeName: @escaping @MainActor (UserProfile) -> Void,
        lessonImporter: (any LessonImporting)?,
        onDidChangeLessons: @escaping @MainActor (LessonChange) -> Void
    ) {
        _viewModel = State(initialValue: SettingsViewModel(
            dependencies: dependencies,
            profileStore: profileStore,
            profileName: name,
            onDidReset: onDidReset,
            onDidChangeName: onDidChangeName,
            lessonImporter: lessonImporter,
            onDidChangeLessons: onDidChangeLessons
        ))
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}

#if DEBUG
#Preview("Root, first launch") {
    RootView(dependencies: PreviewDependencies.withData(), profileStore: InMemoryProfileStore())
}

#Preview("Root, saved name") {
    RootView(
        dependencies: PreviewDependencies.withData(),
        profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample"))
    )
}
#endif
