import BLTDesign
import SwiftUI

/// "Today: 1 of 2 chapters": the day's chapters, the next one ready to start, and the daily-goal mark in green
/// once both are done. Tapping the card or the next chapter starts a session through the same callback the
/// Continue card uses. With nothing to practise it says so and does nothing.
struct TodayCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: HomeTodayCard
    let action: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.heading)
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if card.goalMet {
                    Label("Daily goal met", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.goalMet.foregroundColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(palette.goalMet.backgroundColor, in: Capsule())
                }
            }
            if !card.hasNothingToPractise || !card.goalMet {
                ForEach(card.chapters) { chapter in
                    TodayChapterRow(chapter: chapter, lessonTitle: card.nextLesson?.title, action: action)
                }
            }
            if let note = card.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(card.goalMet ? palette.goalMet.glyphColor : palette.accentColor, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if card.canStart { action() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityIdentifier(AccessibilityID.homeTodayCard)
    }
}
