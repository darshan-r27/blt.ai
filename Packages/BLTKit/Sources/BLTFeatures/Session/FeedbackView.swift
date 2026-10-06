import BLTCatalog
import BLTCore
import BLTDesign
import BLTSession
import SwiftUI

/// The feedback beat. Reading order, visually and for VoiceOver: verdict, canonical form, then
/// the word-by-word gloss, then the note. Colour comes only from `FeedbackTone` and `Palette`.
struct FeedbackView: View {
    let question: Question
    let chosen: Int
    let verdict: Verdict
    /// Whether this item will be asked again in the session (only meaningful after a wrong answer).
    let willReturn: Bool
    let onContinue: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AccessibilityFocusState private var verdictFocused: Bool

    var body: some View {
        let palette = Palette(colorScheme)
        let item = question.item
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                verdictCard(palette)

                VStack(alignment: .leading, spacing: 6) {
                    Text(SessionFeedbackCopy.canonicalLabel)
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondaryColor)
                    Text(item.canonical)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.textPrimaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                if let chosenText = chosenOptionText {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SessionFeedbackCopy.chosenLabel)
                            .font(.footnote)
                            .foregroundStyle(palette.textSecondaryColor)
                        Text(chosenText)
                            .font(.body)
                            .foregroundStyle(palette.textPrimaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }

                if item.reviewStatus == .unreviewed {
                    ReviewStatusBadge()
                }

                if !item.tokens.isEmpty {
                    GlossView(item.tokens.map { (tamil: $0.tamil, english: $0.english) })
                }

                if let note = item.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(palette.textSecondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(palette.backgroundColor)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(SessionFeedbackCopy.continueTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bltPrimary)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.continueButton)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(palette.backgroundColor)
        }
        .onAppear { verdictFocused = true }
    }

    private func verdictCard(_ palette: Palette) -> some View {
        let tone = FeedbackTone(verdict.outcome)
        let pair = palette.tone(tone)
        let copy = SessionFeedbackCopy(verdict: verdict, item: question.item, willReturn: willReturn)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbolName(for: tone))
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.headline)
                    .font(.headline)
                Text(copy.detail)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(pair.foregroundColor)
        .padding(16)
        .background(pair.backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(verdictIdentifier)
        .accessibilityFocused($verdictFocused)
    }

    private var verdictIdentifier: String {
        switch verdict {
        case .correct: AccessibilityID.feedbackCorrect
        case .wrongRegister: AccessibilityID.feedbackWrongRegister
        case .notQuite: AccessibilityID.feedbackNotQuite
        }
    }

    /// A symbol so the verdict is never carried by colour alone.
    private func symbolName(for tone: FeedbackTone) -> String {
        switch tone {
        case .affirm: "checkmark.circle.fill"
        case .nudge: "arrow.left.arrow.right.circle"
        case .neutral: "info.circle"
        }
    }

    /// Shown only when the learner chose something other than the canonical form.
    private var chosenOptionText: String? {
        guard verdict != .correct else { return nil }
        return question.options.first { $0.id == chosen }?.text
    }
}

#if DEBUG
private func feedbackPreview(
    _ item: Item,
    kind: AnswerOption.Kind,
    large: Bool = false
) -> some View {
    let question = sessionPreviewQuestion(item)
    let chosen = question.options.first { $0.kind == kind }?.id ?? 0
    let verdict = question.verdict(for: chosen) ?? .correct
    return FeedbackView(
        question: question,
        chosen: chosen,
        verdict: verdict,
        willReturn: true,
        onContinue: {}
    )
    .environment(\.dynamicTypeSize, large ? .accessibility5 : .large)
}

#Preview("Feedback, correct") {
    feedbackPreview(PreviewCatalog.respectfulItem, kind: .canonical)
}

#Preview("Feedback, wrong register") {
    feedbackPreview(PreviewCatalog.respectfulItem, kind: .registerVariant)
}

#Preview("Feedback, not quite") {
    feedbackPreview(PreviewCatalog.neutralItem, kind: .distractor)
}

#Preview("Feedback, not quite, dark") {
    feedbackPreview(PreviewCatalog.respectfulItem, kind: .distractor)
        .preferredColorScheme(.dark)
}

#Preview("Feedback, wrong register, largest accessibility size") {
    feedbackPreview(PreviewCatalog.respectfulItem, kind: .registerVariant, large: true)
}
#endif
