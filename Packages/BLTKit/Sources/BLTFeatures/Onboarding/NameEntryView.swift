import BLTDesign
import BLTProgress
import SwiftUI

/// First launch only: ask what to call the person. Nothing else is asked (DECISIONS 030).
struct NameEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: NameEntryViewModel

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("What should we call you?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                NameEntryForm(viewModel: viewModel, fieldID: AccessibilityID.nameField, onSubmit: submit)
                Button(action: submit) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bltPrimary)
                .controlSize(.large)
                .accessibilityIdentifier(AccessibilityID.nameContinue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .bltScreenBackground()
    }

    private func submit() {
        Task { await viewModel.submit() }
    }
}

#if DEBUG
/// Owns the view model so previews can start empty, filled, or already showing a message.
private struct NameEntryPreviewHost: View {
    @State private var viewModel = NameEntryViewModel(store: InMemoryProfileStore(), onSaved: { _ in })
    let typed: String
    let submitsAtOnce: Bool

    var body: some View {
        NameEntryView(viewModel: viewModel)
            .task {
                viewModel.updateName(typed)
                if submitsAtOnce {
                    await viewModel.submit()
                }
            }
    }
}

#Preview("Name entry, empty") {
    NameEntryPreviewHost(typed: "", submitsAtOnce: false)
}

#Preview("Name entry, error") {
    NameEntryPreviewHost(typed: "   ", submitsAtOnce: true)
}

#Preview("Name entry, filled") {
    NameEntryPreviewHost(typed: "zz Sample", submitsAtOnce: false)
}

#Preview("Name entry, error, dark") {
    NameEntryPreviewHost(typed: "   ", submitsAtOnce: true)
        .preferredColorScheme(.dark)
}

#Preview("Name entry, error, largest accessibility size") {
    NameEntryPreviewHost(typed: "   ", submitsAtOnce: true)
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
