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
        // A plain top bar instead of the system toolbar: the system's glass bar buttons failed the contrast audit
        // on the lilac sheet, and these read clearly in both appearances.
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(palette.accentColor)
                    .accessibilityIdentifier(AccessibilityID.changeNameCancel)
                Spacer()
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accentColor)
                    .accessibilityIdentifier(AccessibilityID.changeNameSave)
            }
            .font(.body)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Change name")
                        .font(.title2.bold())
                        .foregroundStyle(palette.textPrimaryColor)
                        .accessibilityAddTraits(.isHeader)
                    NameEntryForm(viewModel: viewModel, fieldID: AccessibilityID.changeNameField, onSubmit: save)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .bltScreenBackground()
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
