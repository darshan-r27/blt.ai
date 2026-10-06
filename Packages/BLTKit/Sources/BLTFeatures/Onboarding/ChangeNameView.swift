import BLTDesign
import BLTProgress
import SwiftUI

/// The Change name sheet in Settings: the same field and validation as first launch, with Save and Cancel.
/// Cancel changes nothing.
struct ChangeNameView: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: NameEntryViewModel
    let onCancel: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        NavigationStack {
            ScrollView {
                NameEntryForm(viewModel: viewModel, fieldID: AccessibilityID.changeNameField, onSubmit: save)
                    .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .bltScreenBackground()
            .navigationTitle("Change name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier(AccessibilityID.changeNameCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier(AccessibilityID.changeNameSave)
                }
            }
        }
        // The sheet's own surface is system white or grey; match the page so it does not look like a different app.
        .presentationBackground(palette.backgroundColor)
    }

    private func save() {
        Task { await viewModel.submit() }
    }
}

#if DEBUG
private struct ChangeNamePreviewHost: View {
    @State private var viewModel = NameEntryViewModel(
        store: InMemoryProfileStore(),
        initialName: "zz Sample",
        onSaved: { _ in }
    )

    var body: some View {
        ChangeNameView(viewModel: viewModel, onCancel: {})
    }
}

#Preview("Change name, light") {
    ChangeNamePreviewHost()
}

#Preview("Change name, dark") {
    ChangeNamePreviewHost()
        .preferredColorScheme(.dark)
}
#endif
