import BLTCore
import BLTDesign
import BLTSession
import SwiftUI

/// The question beat: the English prompt and four options. It must never show the word-by-word
/// gloss or anything that reveals the answer; that is the feedback beat's job.
struct QuestionView: View {
    let question: Question
    /// 1-based position of this item in the session, and the number of distinct items.
    let position: Int?
    let total: Int
    let onChoose: @MainActor (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let position {
                    Text("Item \(position) of \(total)")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondaryColor)
                        .accessibilityLabel("Item \(position) of \(total)")
                }

                Text(question.item.sourcePrompt)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                if question.item.reviewStatus == .unreviewed {
                    ReviewStatusBadge()
                }

                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        OptionButton(option.text) {
                            onChoose(option.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(palette.backgroundColor)
    }
}

#if DEBUG
import BLTCatalog

func sessionPreviewQuestion(_ item: Item = PreviewCatalog.respectfulItem) -> Question {
    var random = SessionRandomSource.seeded(1)
    guard let question = QuestionBuilder().makeQuestion(for: item, using: &random) else {
        preconditionFailure("Preview item must build a question")
    }
    return question
}

#Preview("Question, light") {
    QuestionView(question: sessionPreviewQuestion(), position: 1, total: 2, onChoose: { _ in })
        .preferredColorScheme(.light)
}

#Preview("Question, dark") {
    QuestionView(question: sessionPreviewQuestion(), position: 1, total: 2, onChoose: { _ in })
        .preferredColorScheme(.dark)
}

#Preview("Question, reviewed item") {
    QuestionView(
        question: sessionPreviewQuestion(PreviewCatalog.neutralItem),
        position: 2,
        total: 2,
        onChoose: { _ in }
    )
}

#Preview("Question, largest accessibility size") {
    QuestionView(question: sessionPreviewQuestion(), position: 1, total: 2, onChoose: { _ in })
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
