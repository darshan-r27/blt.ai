import BLTDesign
import SwiftUI

/// One chapter of the Today card. A done chapter shows a green check; the next one is a button that starts a
/// session; a later one is a plain row.
struct TodayChapterRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let chapter: HomeTodayChapter
    /// The lesson the next chapter opens; only shown on the next row.
    let lessonTitle: String?
    let action: () -> Void

    var body: some View {
        if chapter.isNext {
            Button(action: action) { row }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Starts a practice session")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(AccessibilityID.homeChapter(chapter.number))
        } else {
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(AccessibilityID.homeChapter(chapter.number))
        }
    }

    private var row: some View {
        let palette = Palette(colorScheme)
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(chapter.isDone ? palette.goalMet.glyphColor : palette.textSecondaryColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Chapter \(chapter.number)")
                    .font(.body.weight(chapter.isNext ? .semibold : .regular))
                    .foregroundStyle(palette.textPrimaryColor)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var symbol: String {
        if chapter.isDone { return "checkmark.circle.fill" }
        return chapter.isNext ? "play.circle.fill" : "circle"
    }

    private var detail: String {
        if chapter.isDone { return "Done" }
        if chapter.isNext { return lessonTitle.map { "\($0), up to 10 questions" } ?? "Up to 10 questions" }
        return "After chapter \(chapter.number - 1)"
    }

    /// "Chapter 1, done", "Chapter 2, zz Lesson, up to 10 questions", "Chapter 2, after chapter 1".
    private var accessibilityLabel: String {
        let state = chapter.isDone ? "done" : (chapter.isNext ? detail : "after chapter \(chapter.number - 1)")
        return "Chapter \(chapter.number), \(state)"
    }
}
