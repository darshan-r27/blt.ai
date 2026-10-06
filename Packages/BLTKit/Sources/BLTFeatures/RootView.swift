import BLTCatalog
import BLTCore
import SwiftUI

/// The app's navigation: Scenarios is home, Progress and Settings push onto its stack, and a
/// session covers the whole screen. Everything it needs arrives through `AppDependencies`.
///
/// Home is reloaded when a session is dismissed and when Settings finishes a reset, so the cards
/// never show figures from before the last answer.
public struct RootView: View {
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
    @State private var home: HomeViewModel
    @State private var path: [Destination] = []
    @State private var session: SessionSelection?

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _home = State(initialValue: HomeViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScenariosView(
                viewModel: home,
                onSelectScenario: select,
                onOpenProgress: { path.append(.progress) },
                onOpenSettings: { path.append(.settings) }
            )
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .progress:
                    ProgressDestination(dependencies: dependencies)
                case .settings:
                    SettingsDestination(dependencies: dependencies, onDidReset: reloadHome)
                }
            }
        }
        .fullScreenCover(item: $session, onDismiss: reloadHome) { selection in
            SessionView(
                viewModel: SessionViewModel(scenario: selection.scenario, dependencies: dependencies),
                onDone: { session = nil }
            )
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

    init(dependencies: AppDependencies, onDidReset: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(dependencies: dependencies, onDidReset: onDidReset))
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}

#if DEBUG
#Preview("Root, fake content") {
    RootView(dependencies: PreviewDependencies.withData())
}
#endif
