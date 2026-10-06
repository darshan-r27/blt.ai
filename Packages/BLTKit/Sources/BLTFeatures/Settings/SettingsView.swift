import BLTDesign
import BLTProgress
import SwiftUI

/// Settings has no preferences in v1: the saved name with Change name, plain statements, and Reset progress.
public struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("About the content") {
                    Text(viewModel.contentStatement)
                    if !viewModel.allContentReviewed {
                        Text("\(viewModel.reviewedCount) of \(viewModel.totalCount) reviewed")
                            .font(.headline)
                    }
                }
                section("Your name") {
                    Text(viewModel.profileName)
                        .font(.headline)
                    Button("Change name") { viewModel.beginChangeName() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(AccessibilityID.settingsChangeName)
                }
                section("Privacy") {
                    Text("This app makes no network requests. Your name stays on this device.")
                    Text("Your progress stays on this device.")
                }
                section("Your progress") {
                    Button("Reset progress", role: .destructive) { viewModel.requestReset() }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isResetting)
                        .accessibilityIdentifier(AccessibilityID.settingsReset)
                    resetStatus(palette: palette)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .bltScreenBackground()
        .navigationTitle("Settings")
        .sheet(item: nameEditorBinding) { editor in
            ChangeNameView(viewModel: editor, onCancel: { viewModel.cancelChangeName() })
        }
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

    /// Dismissing the sheet by swiping it away counts as Cancel.
    private var nameEditorBinding: Binding<NameEntryViewModel?> {
        Binding(
            get: { viewModel.nameEditor },
            set: { editor in
                if editor == nil { viewModel.cancelChangeName() }
            }
        )
    }

    @ViewBuilder
    private func resetStatus(palette: Palette) -> some View {
        switch viewModel.resetOutcome {
        case .succeeded:
            Text("Progress was reset.")
                .font(.body)
                .foregroundStyle(palette.affirm.foregroundColor)
                .padding(12)
                .background(palette.affirm.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
        case .failed:
            Text("Reset did not finish. Your progress may be unchanged. You can try again.")
                .font(.body)
                .foregroundStyle(palette.nudge.foregroundColor)
                .padding(12)
                .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
        case nil:
            EmptyView()
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        let palette = Palette(colorScheme)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.textSecondaryColor)
            content()
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
        }
    }
}

#if DEBUG
private struct SettingsPreviewHost: View {
    @State private var viewModel: SettingsViewModel

    init(_ dependencies: AppDependencies) {
        _viewModel = State(initialValue: SettingsViewModel(
            dependencies: dependencies,
            profileStore: InMemoryProfileStore(initial: UserProfile(name: "zz Sample")),
            profileName: "zz Sample"
        ))
    }

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
        }
    }
}

#Preview("Settings, with name") {
    SettingsPreviewHost(PreviewDependencies.withData())
}

#Preview("Settings, dark") {
    SettingsPreviewHost(PreviewDependencies.withData())
        .preferredColorScheme(.dark)
}

#Preview("Settings, largest accessibility size") {
    SettingsPreviewHost(PreviewDependencies.withData())
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
