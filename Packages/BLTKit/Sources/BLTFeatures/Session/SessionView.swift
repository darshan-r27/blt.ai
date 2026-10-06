import BLTCatalog
import BLTDesign
import BLTProgress
import BLTSession
import SwiftUI

/// Binds a `SessionViewModel` to the question, feedback and summary screens.
public struct SessionView: View {
    @State private var viewModel: SessionViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isConfirmingEnd = false

    /// Length of the crossfade between beats. Replaced by an instant cut under Reduce Motion.
    private static let crossfadeDuration = 0.15

    public init(viewModel: SessionViewModel, onDone: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: viewModel)
        viewModel.setDoneHandler(onDone)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // First in reading order, and outside the crossfade so it does not flicker between beats.
            if showsEndControl {
                SessionEndControl { isConfirmingEnd = true }
            }
            ZStack {
                screen
                    .id(viewModel.beat)
                    .transition(.opacity)
            }
        }
        .alert("End this session?", isPresented: $isConfirmingEnd) {
            Button("End session") { finish() }
                .accessibilityIdentifier(AccessibilityID.endSessionConfirm)
            Button("Keep going", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityID.endSessionKeepGoing)
        } message: {
            Text("Your answers so far are saved.")
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Self.crossfadeDuration),
            value: viewModel.beat
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.saveFailed {
                saveFailedNotice
            }
        }
        .task { await viewModel.start() }
    }

    /// The question and feedback beats carry the End control; every other screen has its own Done.
    private var showsEndControl: Bool {
        switch viewModel.screen {
        case .session(.asking), .session(.feedback): true
        default: false
        }
    }

    /// Leaves the session through the view model, which waits for pending saves and calls
    /// `onDone` once, however many times this is triggered.
    private func finish() {
        Task { await viewModel.endSession() }
    }

    @ViewBuilder private var screen: some View {
        switch viewModel.screen {
        case .loading:
            SessionMessageView(title: "Getting your session ready", message: "One moment.", actions: [])
        case .loadFailed:
            SessionMessageView(
                title: "Could not load your progress",
                message: "Your saved progress could not be read, so the session has not started. "
                    + "Nothing has been changed.",
                actions: [
                    SessionMessageView.Action(id: "retry", title: "Try again", isPrimary: true) {
                        Task { await viewModel.retry() }
                    },
                    SessionMessageView.Action(id: "done", title: "Done", isPrimary: false, run: finish)
                ]
            )
        case .nothingDue:
            SessionMessageView(
                title: "Nothing to study right now",
                message: "Every phrase in this scenario has been seen and none is due yet. "
                    + "You can review the earliest ones anyway.",
                actions: [
                    SessionMessageView.Action(id: "review", title: "Review anyway", isPrimary: true) {
                        viewModel.startReviewAnyway()
                    },
                    SessionMessageView.Action(id: "done", title: "Done", isPrimary: false, run: finish)
                ]
            )
        case .nothingToStudy:
            SessionMessageView(
                title: "Nothing to study here yet",
                message: "This scenario has no phrases to practise.",
                actions: [SessionMessageView.Action(id: "done", title: "Done", isPrimary: true, run: finish)]
            )
        case .session(let state):
            sessionScreen(for: state)
        }
    }

    @ViewBuilder
    private func sessionScreen(for state: SessionState) -> some View {
        switch state {
        case .asking(let question):
            QuestionView(
                question: question,
                position: viewModel.currentPosition,
                total: viewModel.plannedCount,
                onChoose: { viewModel.choose($0) }
            )
        case .feedback(let question, let chosen, let verdict):
            FeedbackView(
                question: question,
                chosen: chosen,
                verdict: verdict,
                willReturn: viewModel.currentItemWillReturn,
                onContinue: { viewModel.advance() }
            )
        case .finished(let result):
            SessionSummaryView(result: result, onDone: finish)
        }
    }

    private var saveFailedNotice: some View {
        let pair = Palette(colorScheme).tone(.neutral)
        return Label {
            Text(SessionViewModel.saveFailedMessage)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .font(.footnote)
        }
        .foregroundStyle(pair.foregroundColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(pair.backgroundColor)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
@MainActor
private func sessionPreviewDependencies(store: some ProgressStore = InMemoryProgressStore()) -> AppDependencies {
    AppDependencies(
        catalog: PreviewCatalog.catalog,
        store: store,
        scheduler: SM2Scheduler(),
        now: { Date(timeIntervalSince1970: 2_000_000) }
    )
}

/// Runs a real session view model so previews show the End control on the real beats.
/// `answered` moves the session to the feedback beat by choosing the canonical option.
private struct SessionPreviewHost: View {
    let answered: Bool
    @State private var viewModel = SessionViewModel(
        scenario: PreviewCatalog.scenario,
        dependencies: sessionPreviewDependencies(),
        random: .seeded(1)
    )

    var body: some View {
        SessionView(viewModel: viewModel, onDone: {})
            .task {
                await viewModel.start()
                guard answered, case .session(.asking(let question)) = viewModel.screen else { return }
                if let option = question.options.first(where: { $0.kind == .canonical }) {
                    viewModel.choose(option.id)
                }
            }
    }
}

#Preview("Question with End control, light") {
    SessionPreviewHost(answered: false)
        .preferredColorScheme(.light)
}

#Preview("Question with End control, largest accessibility size, dark") {
    SessionPreviewHost(answered: false)
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Feedback with End control, light") {
    SessionPreviewHost(answered: true)
        .preferredColorScheme(.light)
}

#Preview("Feedback with End control, largest accessibility size, dark") {
    SessionPreviewHost(answered: true)
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Finished") {
    SessionSummaryView(
        result: SessionResult(correctCount: 6, wrongRegisterCount: 2, wrongCount: 2),
        onDone: {}
    )
}

#Preview("Finished, largest accessibility size, dark") {
    SessionSummaryView(
        result: SessionResult(correctCount: 6, wrongRegisterCount: 2, wrongCount: 2),
        onDone: {}
    )
    .environment(\.dynamicTypeSize, .accessibility5)
    .preferredColorScheme(.dark)
}
#endif
