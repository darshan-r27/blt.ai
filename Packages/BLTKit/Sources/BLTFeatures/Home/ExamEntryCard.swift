import BLTDesign
import SwiftUI

/// The final-exam row near the bottom of Home. Until every level is complete it is a static note with its
/// reason (not a dimmed button, so its text keeps full contrast); once unlocked it is a button.
struct ExamEntryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: ExamEntry
    let action: () -> Void

    var body: some View {
        if entry.isUnlocked {
            Button(action: action) { card }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Opens the final exam")
                .accessibilityIdentifier(AccessibilityID.homeExam)
        } else {
            card
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(AccessibilityID.homeExam)
        }
    }

    private var card: some View {
        let palette = Palette(colorScheme)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Final exam")
                .font(.headline)
                .foregroundStyle(palette.textPrimaryColor)
            Text(entry.summary)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
            if let line = entry.bestLine {
                Text(line)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.accentColor, lineWidth: entry.isUnlocked ? 2 : 0))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private var accessibilityLabel: String {
        ["Final exam", entry.summary, entry.bestLine].compactMap { $0 }.joined(separator: ", ")
    }
}
