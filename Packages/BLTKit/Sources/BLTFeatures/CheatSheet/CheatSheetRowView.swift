import BLTDesign
import SwiftUI

/// One word on a sheet: the word, its English meaning, the example phrase, and the "Unreviewed draft" label
/// when any phrase using the word is unreviewed. VoiceOver reads the word and meaning as one element.
struct CheatSheetRowView: View {
    @Environment(\.colorScheme) private var colorScheme

    let row: CheatSheetViewModel.Row

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.entry.word)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                if !row.entry.meaning.isEmpty {
                    Text(row.entry.meaning)
                        .font(.body)
                        .foregroundStyle(palette.textPrimaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityIdentifier(AccessibilityID.cheatSheetRow(row.index))
            Text(row.entry.example)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            if row.isUnreviewed {
                unreviewedLabel(palette: palette)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.outlineColor, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func unreviewedLabel(palette: Palette) -> some View {
        let tone = palette.tone(.neutral)
        return Text(CheatSheetLabels.unreviewed)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.backgroundColor, in: Capsule())
            .accessibilityIdentifier(AccessibilityID.cheatSheetRowUnreviewed(row.index))
    }
}
