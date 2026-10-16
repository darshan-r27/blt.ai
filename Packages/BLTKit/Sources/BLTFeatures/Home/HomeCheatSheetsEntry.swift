import BLTDesign
import SwiftUI

/// The "Cheat sheets" row on Home: opens the list of every topic's sheet, unlocked or not.
struct HomeCheatSheetsEntry: View {
    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        Button(action: action) {
            HStack(spacing: 12) {
                Text(CheatSheetLabels.homeEntryTitle)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textSecondaryColor)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.outlineColor, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CheatSheetLabels.homeEntryTitle)
        .accessibilityHint("Opens the word lists of your topics")
        .accessibilityIdentifier(AccessibilityID.homeCheatSheets)
    }
}
