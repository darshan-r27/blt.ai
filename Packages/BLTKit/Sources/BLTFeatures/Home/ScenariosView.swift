import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI

/// The home screen: a calm list of scenarios. Navigation is injected; the owner decides what the
/// closures do.
public struct ScenariosView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var viewModel: HomeViewModel

    private let name: String?
    private let onSelectScenario: (ScenarioID) -> Void
    private let onOpenProgress: () -> Void
    private let onOpenSettings: () -> Void

    public init(
        viewModel: HomeViewModel,
        name: String?,
        onSelectScenario: @escaping (ScenarioID) -> Void,
        onOpenProgress: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.name = name
        self.onSelectScenario = onSelectScenario
        self.onOpenProgress = onOpenProgress
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .bltScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Progress", systemImage: "chart.bar", action: onOpenProgress)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape", action: onOpenSettings)
                }
            }
            .task { await viewModel.load() }
            .confirmationDialog(
                "Reset all progress?",
                isPresented: $viewModel.isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("Reset progress", role: .destructive) {
                    Task { await viewModel.confirmReset() }
                }
                Button("Cancel", role: .cancel) { viewModel.cancelReset() }
            } message: {
                Text(
                    "This erases your review schedule and answer history on this device. "
                        + "It cannot be undone. Your name is not erased."
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.loadError {
            errorState(error)
        } else if !viewModel.hasLoaded {
            ProgressView()
        } else if viewModel.scenarios.isEmpty {
            emptyState
        } else {
            scenarioList
        }
    }

    private var scenarioList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let greeting {
                    ShimmerText(greeting)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier(AccessibilityID.greeting)
                }
                Text("Scenarios")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette(colorScheme).textPrimaryColor)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(viewModel.scenarios) { scenario in
                    ScenarioCard(summary: scenario) { onSelectScenario(scenario.id) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// "Hi <name>", or `nil` (nothing is shown) when there is no usable name.
    private var greeting: String? {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return HomeViewModel.greeting(forName: name)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No scenarios",
            systemImage: "tray",
            description: Text("This copy of the app has no lesson content to show.")
        )
    }

    private func errorState(_ error: ProgressStoreError) -> some View {
        let palette = Palette(colorScheme)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your saved progress can't be opened")
                    .font(.title3.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                Text(explanation(for: error))
                    .font(.body)
                    .foregroundStyle(palette.textPrimaryColor)
                if viewModel.resetError != nil {
                    Text("Reset did not finish. Your progress file may be unchanged. You can try again.")
                        .font(.body)
                        .foregroundStyle(palette.nudge.foregroundColor)
                        .padding(12)
                        .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
                }
                if viewModel.canOfferReset {
                    Button("Reset progress…", role: .destructive) { viewModel.requestReset() }
                        .buttonStyle(.bltPrimary)
                        .accessibilityIdentifier(AccessibilityID.settingsReset)
                } else {
                    Button("Try again") { Task { await viewModel.load() } }
                        .buttonStyle(.bltPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func explanation(for error: ProgressStoreError) -> String {
        switch error {
        case .corrupt:
            "The progress file is damaged. Nothing has been changed or deleted. "
                + "You can reset it to start over, which erases all progress."
        case .unsupportedSchemaVersion:
            "The progress file was saved by a newer version of the app. Nothing has been changed or deleted. "
                + "You can reset it to start over, which erases all progress."
        case .unreadable, .writeFailed, .eraseFailed:
            "The progress file could not be read. Nothing has been changed or deleted. Please try again."
        }
    }
}

#if DEBUG
private struct HomePreviewHost: View {
    @State private var viewModel: HomeViewModel

    init(_ dependencies: AppDependencies) {
        _viewModel = State(initialValue: HomeViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ScenariosView(
                viewModel: viewModel,
                name: "zz Sample",
                onSelectScenario: { _ in },
                onOpenProgress: {},
                onOpenSettings: {}
            )
        }
    }
}

#Preview("Home, with data") {
    HomePreviewHost(PreviewDependencies.withData())
}

#Preview("Home, empty progress") {
    HomePreviewHost(PreviewDependencies.empty())
}

#Preview("Home, with data, dark") {
    HomePreviewHost(PreviewDependencies.withData())
        .preferredColorScheme(.dark)
}

#Preview("Home, with data, largest accessibility size") {
    HomePreviewHost(PreviewDependencies.withData())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Home, corrupt progress file") {
    HomePreviewHost(PreviewDependencies.failing(.corrupt))
}

#Preview("Home, unreadable progress file") {
    HomePreviewHost(PreviewDependencies.failing(.unreadable))
}
#endif
