import BLTDesign
import BLTSession
import SwiftUI

/// Binds an `ExamViewModel` to the intro, question and result screens. Shown full screen like a session.
struct ExamView: View {
    @State private var viewModel: ExamViewModel
    private let onDone: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: ExamViewModel, onDone: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDone = onDone
    }

    var body: some View {
        switch viewModel.phase {
        case .intro:
            intro
        case .asking:
            asking
        case .finished:
            finished
        }
    }

    // MARK: Intro

    private var intro: some View {
        let palette = Palette(colorScheme)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Final exam")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "\(viewModel.total) questions in one sitting. You will not see whether an answer was right "
                        + "until the end, and you cannot go back. Pass with \(viewModel.correctNeededToPass) "
                        + "correct. Your answers do not change your review schedule."
                )
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
                Text(ExamViewModel.recognitionStatement(for: viewModel.language))
                    .font(.body)
                    .foregroundStyle(palette.textSecondaryColor)
                if viewModel.startFailed {
                    notice("The exam could not be started, so nothing was recorded. Please try again later.")
                }
                Button("Begin the exam") { viewModel.begin() }
                    .buttonStyle(.bltPrimary)
                    .controlSize(.large)
                    .accessibilityIdentifier(AccessibilityID.examStart)
                Button("Not now", action: onDone)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier(AccessibilityID.examDone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(palette.backgroundColor)
    }

    // MARK: Questions

    @ViewBuilder private var asking: some View {
        if let question = viewModel.question {
            VStack(spacing: 0) {
                SessionEndControl(
                    onTap: { viewModel.requestEnd() },
                    title: "End exam",
                    identifier: AccessibilityID.examEndButton
                )
                QuestionView(
                    question: question,
                    position: viewModel.position,
                    total: viewModel.total,
                    onChoose: { viewModel.choose($0) }
                )
                .id(viewModel.position)
            }
            .alert("End the exam?", isPresented: $viewModel.isConfirmingEnd) {
                Button("End exam", role: .destructive) { viewModel.confirmEnd() }
                    .accessibilityIdentifier(AccessibilityID.examEndConfirm)
                Button("Keep going", role: .cancel) { viewModel.cancelEnd() }
                    .accessibilityIdentifier(AccessibilityID.examKeepGoing)
            } message: {
                Text("Questions you have not answered count as wrong. Your score is saved.")
            }
        }
    }

    // MARK: Result

    @ViewBuilder private var finished: some View {
        if let result = viewModel.result {
            let palette = Palette(colorScheme)
            let tone = palette.tone(result.passed ? .affirm : .nudge)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(result.passed ? "You passed" : "Not passed yet")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.textPrimaryColor)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(result.correct) of \(result.total) correct")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tone.foregroundColor)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tone.backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityIdentifier(AccessibilityID.examResult)
                    Text("The pass mark is \(viewModel.correctNeededToPass) of \(result.total).")
                        .font(.body)
                        .foregroundStyle(palette.textSecondaryColor)
                    weakLevelsNote(palette: palette)
                    Text(ExamViewModel.recognitionStatement(for: viewModel.language))
                        .font(.body)
                        .foregroundStyle(palette.textSecondaryColor)
                    if viewModel.saveFailed {
                        notice("This result could not be saved, so it will not appear in your best score.")
                    }
                    Button("Done", action: onDone)
                        .buttonStyle(.bltPrimary)
                        .controlSize(.large)
                        .accessibilityIdentifier(AccessibilityID.examDone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(palette.backgroundColor)
        }
    }

    @ViewBuilder private func weakLevelsNote(palette: Palette) -> some View {
        let levels = viewModel.weakLevels
        if !levels.isEmpty {
            let names = levels.map { "Level \($0)" }.formatted(.list(type: .and))
            Text("Worth another look: \(names).")
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
        }
    }

    private func notice(_ message: String) -> some View {
        let palette = Palette(colorScheme)
        return Text(message)
            .font(.body)
            .foregroundStyle(palette.nudge.foregroundColor)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
import BLTCatalog
import BLTProgress

@MainActor
private func previewModel(answering count: Int = 0, finishing: Bool = false) -> ExamViewModel {
    let items = PreviewCatalog.leveledCatalog.scenarios.flatMap(\.items)
    let paper = ExamPaper(sources: items.enumerated().map { index, item in
        ExamQuestionSource(item: item, level: index % 2 == 0 ? 1 : 2)
    })
    let model = ExamViewModel(
        paper: paper,
        language: .telugu,
        results: InMemoryExamResultStore(),
        now: { Date(timeIntervalSince1970: 0) },
        random: .seeded(3)
    )
    guard count > 0 || finishing else { return model }
    model.begin()
    for _ in 0..<count {
        if let option = model.question?.options.first(where: { $0.kind == .canonical }) { model.choose(option.id) }
    }
    if finishing { model.confirmEnd() }
    return model
}

#Preview("Exam, intro") {
    ExamView(viewModel: previewModel(), onDone: {})
}

#Preview("Exam, question") {
    ExamView(viewModel: previewModel(answering: 1), onDone: {})
}

#Preview("Exam, result, dark") {
    ExamView(viewModel: previewModel(answering: 2, finishing: true), onDone: {})
        .preferredColorScheme(.dark)
}

#Preview("Exam, question, largest accessibility size") {
    ExamView(viewModel: previewModel(answering: 1), onDone: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
