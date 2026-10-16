import BLTDesign
import SwiftUI

/// One scenario on Home: title, subtitle and one completion bar with its percent, tappable to practise it.
/// A finished topic also carries a "Cheat sheet" button. The two buttons are siblings, never nested, so each
/// has its own accessibility element and identifier. No streaks, points or ranks.
struct ScenarioCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summary: ScenarioSummary
    let action: () -> Void
    /// Opens this topic's cheat sheet. `nil` while the topic is not unlocked: then no button is shown (the
    /// cheat sheet list explains what is locked, so the card stays uncluttered).
    var onOpenCheatSheet: (() -> Void)?

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 0) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Opens a practice session for this scenario")
            .accessibilityIdentifier(AccessibilityID.scenarioCard(summary.id.rawValue))
            if let onOpenCheatSheet {
                Button(CheatSheetLabels.cardButtonTitle, systemImage: "list.bullet.rectangle", action: onOpenCheatSheet)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .accessibilityHint("Opens the word list for this topic")
                    .accessibilityIdentifier(AccessibilityID.cheatSheetButton(summary.id.rawValue))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.outlineColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Title, then subtitle, then completion: "zz A, zz sub A, 35 percent complete".
    private var accessibilityLabel: String {
        let completion = CompletionBar.accessibilityValue(forPercent: summary.completionPercent)
        return "\(summary.title), \(summary.subtitle), \(completion)"
    }
}
