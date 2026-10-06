import BLTDesign
import BLTProgress
import SwiftUI

/// One learner's own practice figures. No charts, ranks, streaks or comparisons.
public struct ProgressScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    private let viewModel: ProgressViewModel

    public init(viewModel: ProgressViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let error = viewModel.loadError {
                    Text(message(for: error))
                        .font(.body)
                        .foregroundStyle(palette.textPrimaryColor)
                } else if let summary = viewModel.summary {
                    figures(summary, palette: palette)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(palette.backgroundColor)
        .navigationTitle("Progress")
        .task { await viewModel.load() }
    }

    private func figures(_ summary: ProgressSummary, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Register accuracy")
                    .font(.headline)
                    .foregroundStyle(palette.textSecondaryColor)
                Text(accuracyText(summary.registerAccuracy))
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityIdentifier(AccessibilityID.progressRegisterAccuracy)
                Text("This measures how often you chose the right form for the right person.")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
                if summary.registerAccuracy == nil {
                    Text("It appears once you have answered an item that has a casual and a respectful form.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondaryColor)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 12) {
                figureRow("Items learned", value: summary.learnedCount, id: AccessibilityID.progressLearned)
                figureRow("Items due for review", value: summary.dueCount, id: AccessibilityID.progressDue)
                figureRow("Attempts so far", value: summary.attemptCount, id: nil)
            }

            Text("These figures are your own practice on this device. They are not compared with anyone else.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondaryColor)
        }
    }

    @ViewBuilder
    private func figureRow(_ title: String, value: Int, id: String?) -> some View {
        let palette = Palette(colorScheme)
        let row = HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
            Spacer()
            Text(value.formatted())
                .font(.title3.bold())
                .foregroundStyle(palette.textPrimaryColor)
        }
        .padding(16)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        if let id {
            row.accessibilityIdentifier(id)
        } else {
            row
        }
    }

    private func accuracyText(_ accuracy: Double?) -> String {
        guard let accuracy else { return "—" }
        return accuracy.formatted(.percent.precision(.fractionLength(0)))
    }

    private func message(for error: ProgressStoreError) -> String {
        switch error {
        case .corrupt, .unsupportedSchemaVersion:
            "Your saved progress can't be opened, so there is nothing to show yet. "
                + "You can reset it from the Scenarios screen."
        case .unreadable, .writeFailed, .eraseFailed:
            "Your saved progress could not be read. Please go back and try again."
        }
    }
}

#if DEBUG
private struct ProgressPreviewHost: View {
    @State private var viewModel: ProgressViewModel

    init(_ dependencies: AppDependencies) {
        _viewModel = State(initialValue: ProgressViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ProgressScreen(viewModel: viewModel)
        }
    }
}

#Preview("Progress, with data") {
    ProgressPreviewHost(PreviewDependencies.withData())
}

#Preview("Progress, no register accuracy yet") {
    ProgressPreviewHost(PreviewDependencies.empty())
}
#endif
