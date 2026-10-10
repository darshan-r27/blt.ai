import BLTCore
import BLTDesign
import BLTProgress
import SwiftUI

/// Onboarding step after the name: which language does the learner want to learn? Two large options,
/// then Continue. Also shown to a profile saved before the language existed (DECISIONS 043).
struct LanguageChoiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: LanguageChoiceViewModel

    /// Wired to the gate: saving the choice moves on to Home.
    init(gate: ProfileGateViewModel, profile: UserProfile) {
        _viewModel = State(initialValue: gate.makeLanguageChoiceViewModel(profile: profile))
    }

    /// For previews, which supply their own view model.
    init(viewModel: LanguageChoiceViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Which language do you want to learn?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 12) {
                    ForEach(viewModel.options, id: \.self) { language in
                        optionRow(language, palette: palette)
                    }
                }
                Text("You can change this later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondaryColor)
                if let message = viewModel.problemMessage {
                    problemNotice(message, palette: palette)
                }
                Button(action: submit) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bltPrimary)
                .controlSize(.large)
                .disabled(!viewModel.canContinue)
                .accessibilityIdentifier(AccessibilityID.languageContinue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .bltScreenBackground()
        .onChange(of: viewModel.problemMessage) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    private func optionRow(_ language: CourseLanguage, palette: Palette) -> some View {
        let isSelected = viewModel.selection == language
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                viewModel.select(language)
            }
        } label: {
            HStack(spacing: 12) {
                Text(language.displayName)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                // A symbol as well as colour, so the choice never relies on colour alone.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.textPrimaryColor)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(isSelected ? palette.accentTintColor : palette.surfaceColor, in: shape)
            .overlay(
                shape.strokeBorder(
                    isSelected ? palette.accentColor : palette.outlineColor,
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.languageOption(language.rawValue))
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
    }

    private func submit() {
        Task { await viewModel.submit() }
    }
}

#if DEBUG
/// Owns the view model so previews can start empty or with a choice already made.
private struct LanguageChoicePreviewHost: View {
    @State private var viewModel = LanguageChoiceViewModel(
        store: InMemoryProfileStore(),
        profile: UserProfile(name: "zz Sample"),
        onSaved: { _ in }
    )
    let chosen: CourseLanguage?

    var body: some View {
        LanguageChoiceView(viewModel: viewModel)
            .task {
                if let chosen {
                    viewModel.select(chosen)
                }
            }
    }
}

#Preview("Language, nothing chosen") {
    LanguageChoicePreviewHost(chosen: nil)
}

#Preview("Language, chosen") {
    LanguageChoicePreviewHost(chosen: .telugu)
}

#Preview("Language, chosen, dark") {
    LanguageChoicePreviewHost(chosen: .tamil)
        .preferredColorScheme(.dark)
}

#Preview("Language, largest accessibility size") {
    LanguageChoicePreviewHost(chosen: .tamil)
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
