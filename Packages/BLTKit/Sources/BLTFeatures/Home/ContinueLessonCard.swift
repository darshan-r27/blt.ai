import BLTDesign
import SwiftUI

/// "Continue": the suggested next lesson, shown near the top of Home. It opens the lesson exactly as the lesson's
/// own card does. It is a suggestion only; nothing is locked (DECISIONS 039).
struct ContinueLessonCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summary: ScenarioSummary
    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                Text(summary.title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                Text(summary.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
                CompletionBar(percent: summary.completionPercent)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.accentColor, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the next lesson to practise")
        .accessibilityIdentifier(AccessibilityID.homeContinueLesson)
    }

    /// "Continue, zz A, zz sub A, 35 percent complete".
    private var accessibilityLabel: String {
        let completion = CompletionBar.accessibilityValue(forPercent: summary.completionPercent)
        return "Continue, \(summary.title), \(summary.subtitle), \(completion)"
    }
}
