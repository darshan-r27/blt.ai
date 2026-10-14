import BLTDesign
import BLTProgress
import SwiftUI

/// The pre-prompt: one calm reason first, then Allow (which shows the system's own question) or Not now.
/// No fixed heights, so it scrolls instead of clipping at the largest text size. No red.
struct NotificationsPromptView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let viewModel: NotificationsPromptViewModel

    init(viewModel: NotificationsPromptViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "bell")
                    .font(.largeTitle)
                    .foregroundStyle(palette.accentColor)
                    .accessibilityHidden(true)
                Text(NotificationsPromptViewModel.reason)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Text(NotificationsPromptViewModel.detail)
                    .font(.body)
                    .foregroundStyle(palette.textSecondaryColor)
                if viewModel.saveFailed {
                    Text(NotificationsPromptViewModel.saveFailureMessage)
                        .font(.body)
                        .foregroundStyle(palette.nudge.foregroundColor)
                        .padding(12)
                        .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
                }
                Button("Allow reminders") { Task { await viewModel.allow() } }
                    .buttonStyle(.bltPrimary)
                    .disabled(viewModel.isWorking)
                    .accessibilityHint("Shows the iOS question about notifications")
                    .accessibilityIdentifier(AccessibilityID.notificationsPromptAllow)
                Button("Not now") { Task { await viewModel.notNow() } }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isWorking)
                    .accessibilityHint("You can turn reminders on later in Settings")
                    .accessibilityIdentifier(AccessibilityID.notificationsPromptNotNow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .bltScreenBackground()
        .accessibilityIdentifier(AccessibilityID.notificationsPrompt)
    }
}

#if DEBUG
@MainActor
private func previewModel() -> NotificationsPromptViewModel {
    NotificationsPromptViewModel(
        reminders: FakeReminderScheduler(status: .notDetermined),
        preferences: InMemoryPracticePreferencesStore()
    )
}

#Preview("Notifications prompt") {
    NotificationsPromptView(viewModel: previewModel())
}

#Preview("Notifications prompt, dark") {
    NotificationsPromptView(viewModel: previewModel())
        .preferredColorScheme(.dark)
}

#Preview("Notifications prompt, largest size") {
    NotificationsPromptView(viewModel: previewModel())
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
