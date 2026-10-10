import BLTDesign
import SwiftUI

/// The tappable header of one level: "Level 1: Survival", its completion, and a chevron showing whether the
/// lessons below it are shown. It is a button because tapping opens or closes the level.
///
/// The text wraps instead of truncating, so it stays readable at the largest Dynamic Type size.
struct LevelHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let section: HomeLevelSection
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.headerTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.textPrimaryColor)
                        .fixedSize(horizontal: false, vertical: true)
                    CompletionBar(percent: section.completionPercent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondaryColor)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.accessibilityLabel)
        .accessibilityValue(section.accessibilityValue(isExpanded: isExpanded))
        .accessibilityHint(isExpanded ? "Hides the lessons in this level" : "Shows the lessons in this level")
        .accessibilityAddTraits([.isHeader, .isButton])
        .accessibilityIdentifier(AccessibilityID.homeLevel(section.number))
    }
}
