import BLTDesign
import BLTProgress
import SwiftUI

/// Shown instead of Home when the saved name cannot be read. Never silent, never a silent repair:
/// a damaged file is erased only after the user confirms Start over, and progress is not touched.
struct ProfileLoadProblemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var gate: ProfileGateViewModel

    let error: ProfileStoreError

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(palette.textPrimaryColor)
                if gate.startOverError != nil {
                    Text("Starting over did not finish. Nothing was changed. You can try again.")
                        .font(.body)
                        .foregroundStyle(palette.nudge.foregroundColor)
                        .padding(12)
                        .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
                }
                action
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .bltScreenBackground()
        .alert("Start over?", isPresented: $gate.isConfirmingStartOver) {
            Button("Start over") {
                Task { await gate.confirmStartOver() }
            }
            Button("Cancel", role: .cancel) { gate.cancelStartOver() }
        } message: {
            Text("This removes the saved name from this device so you can enter it again. Your progress is not erased.")
        }
    }

    @ViewBuilder private var action: some View {
        if gate.canOfferStartOver {
            Button("Start over") { gate.requestStartOver() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        } else {
            Button("Try again") { Task { await gate.retry() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var title: String {
        switch error {
        case .corrupt, .unsupportedSchemaVersion: "Your saved name can't be read"
        case .unreadable, .writeFailed, .eraseFailed: "Your saved name could not be opened"
        }
    }

    private var explanation: String {
        switch error {
        case .corrupt:
            "The file that holds your name is damaged. Nothing has been changed or deleted. "
                + "You can start over and enter your name again. Your progress is not affected."
        case .unsupportedSchemaVersion:
            "The file that holds your name was saved by a newer version of the app. Nothing has been changed "
                + "or deleted. You can start over and enter your name again. Your progress is not affected."
        case .unreadable, .writeFailed, .eraseFailed:
            "The file that holds your name could not be read right now. Nothing has been changed or deleted. "
                + "Please try again."
        }
    }
}

#if DEBUG
private struct ProfileLoadProblemPreviewHost: View {
    @State private var gate: ProfileGateViewModel
    private let error: ProfileStoreError

    init(_ error: ProfileStoreError) {
        self.error = error
        _gate = State(initialValue: ProfileGateViewModel(store: PreviewFailingProfileStore(loadError: error)))
    }

    var body: some View {
        ProfileLoadProblemView(gate: gate, error: error)
            .task { await gate.load() }
    }
}

#Preview("Profile damaged") {
    ProfileLoadProblemPreviewHost(.corrupt)
}

#Preview("Profile damaged, dark") {
    ProfileLoadProblemPreviewHost(.corrupt)
        .preferredColorScheme(.dark)
}

#Preview("Profile unreadable") {
    ProfileLoadProblemPreviewHost(.unreadable)
}

#Preview("Profile damaged, largest accessibility size") {
    ProfileLoadProblemPreviewHost(.corrupt)
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
