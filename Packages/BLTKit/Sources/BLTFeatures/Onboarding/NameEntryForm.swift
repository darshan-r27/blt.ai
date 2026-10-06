import BLTDesign
import SwiftUI

/// The shared body of the first-launch Name entry screen and the Change name sheet: one labelled
/// text field, the privacy line, and a calm inline message when something needs attention.
struct NameEntryForm: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    let viewModel: NameEntryViewModel
    let fieldID: String
    let onSubmit: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("Your name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondaryColor)
                .accessibilityHidden(true)
            TextField("Your name", text: nameBinding)
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .padding(12)
                .frame(minHeight: 44)
                .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.outlineColor, lineWidth: 1)
                )
                .accessibilityIdentifier(fieldID)
            Text("Stays on this device. No account needed.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondaryColor)
            if let message = viewModel.problemMessage {
                problemNotice(message, palette: palette)
            }
        }
        .onAppear { isFocused = true }
        .onChange(of: viewModel.problemMessage) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { viewModel.name },
            set: { viewModel.updateName($0) }
        )
    }

    /// Nudge tone, never red. The symbol means the message does not rely on colour alone.
    private func problemNotice(_ message: String, palette: Palette) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(palette.nudge.foregroundColor)
        .padding(12)
        .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.nameError)
    }
}
