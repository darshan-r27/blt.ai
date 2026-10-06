import BLTDesign
import SwiftUI

/// One tappable scenario on Home: title, subtitle and plain counts. No streaks, points or ranks.
struct ScenarioCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summary: ScenarioSummary
    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.title)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                Text(summary.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
                Text("\(summary.dueCount) due · \(summary.newCount) new · \(summary.learnedCount) learned")
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimaryColor)
                Text("\(summary.answeredCount) of \(summary.totalCount) answered")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondaryColor)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.outlineColor, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a practice session for this scenario")
        .accessibilityIdentifier(AccessibilityID.scenarioCard(summary.id.rawValue))
    }
}
