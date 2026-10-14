import BLTDesign
import BLTProgress
import SwiftUI

/// The "Daily practice" part of Settings: the reminders toggle, quiet hours, and the read-only daily goal.
/// It also owns the permission pre-prompt sheet that the toggle can open. Rows stack on the left and grow
/// with the text; nothing has a fixed height.
struct DailyPracticeSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private let model: DailyPracticeSettingsModel

    init(model: DailyPracticeSettingsModel) {
        self.model = model
    }

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily practice")
                .font(.headline)
                .foregroundStyle(palette.textSecondaryColor)
                .accessibilityAddTraits(.isHeader)
            remindersRow
            if model.notificationsAreDenied {
                deniedExplanation(palette: palette)
            }
            quietHoursRows
            LabeledContent("Daily goal", value: model.dailyGoalText)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.settingsDailyGoal)
            if let message = model.noticeMessage {
                Text(message)
                    .font(.body)
                    .foregroundStyle(palette.nudge.foregroundColor)
                    .padding(12)
                    .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .font(.body)
        .foregroundStyle(palette.textPrimaryColor)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.settingsDailyPractice)
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // Back from iOS Settings: the learner may have changed the notification permission there.
            if phase == .active { Task { await model.refresh() } }
        }
        .sheet(item: promptBinding) { prompt in
            NotificationsPromptView(viewModel: prompt)
                .presentationDetents([.medium, .large])
        }
    }

    private var remindersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Reminders", isOn: remindersBinding)
                .disabled(!model.canChangeReminders)
                .accessibilityIdentifier(AccessibilityID.settingsReminders)
            Text("Up to two short reminders before your streak would lapse.")
                .font(.footnote)
                .foregroundStyle(Palette(colorScheme).textSecondaryColor)
        }
    }

    private func deniedExplanation(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DailyPracticeSettingsModel.deniedExplanation)
                .accessibilityIdentifier(AccessibilityID.settingsNotificationsDenied)
            Button("Open iOS Settings") { model.openIOSSettings() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.settingsNotificationsOpenSettings)
        }
    }

    private var quietHoursRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            hourPicker("Quiet hours start", selection: quietStartBinding, id: AccessibilityID.settingsQuietHoursStart)
            hourPicker("Quiet hours end", selection: quietEndBinding, id: AccessibilityID.settingsQuietHoursEnd)
            Text("No reminders during quiet hours. One that falls inside them arrives a little earlier instead.")
                .font(.footnote)
                .foregroundStyle(Palette(colorScheme).textSecondaryColor)
        }
    }

    private func hourPicker(_ title: String, selection: Binding<Int>, id: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(model.hourLabel(hour)).tag(hour)
            }
        }
        .pickerStyle(.menu)
        .disabled(!model.canChangeQuietHours)
        .accessibilityIdentifier(id)
    }

    private var quietStartBinding: Binding<Int> {
        Binding(
            get: { model.quietStartHour },
            set: { start in Task { await model.setQuietHours(startHour: start, endHour: model.quietEndHour) } }
        )
    }

    private var quietEndBinding: Binding<Int> {
        Binding(
            get: { model.quietEndHour },
            set: { end in Task { await model.setQuietHours(startHour: model.quietStartHour, endHour: end) } }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { model.remindersAreOn },
            set: { enabled in Task { await model.setRemindersEnabled(enabled) } }
        )
    }

    /// Swiping the sheet away counts as Not now.
    private var promptBinding: Binding<NotificationsPromptViewModel?> {
        Binding(
            get: { model.prompt },
            set: { prompt in
                if prompt == nil, let open = model.prompt {
                    Task { await open.dismissed() }
                }
            }
        )
    }
}

#if DEBUG
@MainActor
private func previewModel(status: ReminderAuthorization, enabled: Bool = true) -> DailyPracticeSettingsModel {
    DailyPracticeSettingsModel(
        store: InMemoryPracticePreferencesStore(initial: PracticePreferences(remindersEnabled: enabled)),
        reminders: FakeReminderScheduler(status: status),
        calendar: .current,
        onPracticeSettingsChanged: {},
        openSystemSettings: {}
    )
}

#Preview("Daily practice, reminders on") {
    DailyPracticeSection(model: previewModel(status: .authorized))
        .padding(16)
        .bltScreenBackground()
}

#Preview("Daily practice, permission not asked yet") {
    DailyPracticeSection(model: previewModel(status: .notDetermined))
        .padding(16)
        .bltScreenBackground()
}

#Preview("Daily practice, notifications denied, dark") {
    DailyPracticeSection(model: previewModel(status: .denied))
        .padding(16)
        .bltScreenBackground()
        .preferredColorScheme(.dark)
}

#Preview("Daily practice, largest size") {
    ScrollView {
        DailyPracticeSection(model: previewModel(status: .denied))
            .padding(16)
    }
    .bltScreenBackground()
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
