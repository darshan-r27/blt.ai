import BLTDesign
import SwiftUI

/// One tappable scenario on Home: title, subtitle and one completion bar with its percent.
/// No streaks, points or ranks.
struct ScenarioCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summary: ScenarioSummary
    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
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
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.outlineColor, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens a practice session for this scenario")
        .accessibilityIdentifier(AccessibilityID.scenarioCard(summary.id.rawValue))
    }

    /// Title, then subtitle, then completion: "zz A, zz sub A, 35 percent complete".
    private var accessibilityLabel: String {
        let completion = CompletionBar.accessibilityValue(forPercent: summary.completionPercent)
        return "\(summary.title), \(summary.subtitle), \(completion)"
    }
}
