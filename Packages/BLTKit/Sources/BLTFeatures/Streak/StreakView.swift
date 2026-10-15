import BLTDesign
import BLTProgress
import SwiftUI

/// The streak screen, shown full screen like a session or the exam: the count, the deadline in plain words,
/// the longest streak, freezes and goal days, and a month calendar that pages back to the first practised
/// month. Done leaves.
struct StreakView: View {
    @State private var viewModel: StreakViewModel
    private let onDone: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: StreakViewModel, onDone: @escaping @MainActor () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDone = onDone
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your streak")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                content(palette: palette)
                Button("Done", action: onDone)
                    .buttonStyle(.bltPrimary)
                    .controlSize(.large)
                    .accessibilityIdentifier(AccessibilityID.streakDone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.streakScreen)
        }
        .background(palette.backgroundColor)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func content(palette: Palette) -> some View {
        switch viewModel.phase {
        case .loading:
            Text("One moment.")
                .font(.body)
                .foregroundStyle(palette.textSecondaryColor)
        case .failed:
            failed(palette: palette)
        case .loaded:
            loaded(palette: palette)
        }
    }

    private func loaded(palette: Palette) -> some View {
        let summary = viewModel.summary
        return VStack(alignment: .leading, spacing: 20) {
            StreakFlameBadge(count: summary.currentStreak, size: .large, freezesLeft: summary.freezesAvailable)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityID.streakCount)
            Text(viewModel.deadlineText)
                .font(.body)
                .foregroundStyle(palette.textPrimaryColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.streakDeadline)
            VStack(spacing: 10) {
                statRow("Longest streak", StreakCopy.dayCount(summary.longestStreak), AccessibilityID.streakLongest)
                statRow("Freezes left", "\(summary.freezesAvailable)", AccessibilityID.streakFreezes)
                statRow("Daily goal days", StreakCopy.dayCount(summary.goalDays), AccessibilityID.streakGoalDays)
            }
            calendarSection(palette: palette)
        }
    }

    private func statRow(_ title: String, _ value: String, _ identifier: String) -> some View {
        let palette = Palette(colorScheme)
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .foregroundStyle(palette.textPrimaryColor)
        .padding(14)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier(identifier)
    }

    private func calendarSection(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                monthButton(
                    "chevron.left",
                    label: viewModel.previousMonthLabel,
                    isEnabled: viewModel.canShowPreviousMonth,
                    identifier: AccessibilityID.streakPreviousMonth
                ) { viewModel.showPreviousMonth() }
                Spacer(minLength: 0)
                monthButton(
                    "chevron.right",
                    label: viewModel.nextMonthLabel,
                    isEnabled: viewModel.canShowNextMonth,
                    identifier: AccessibilityID.streakNextMonth
                ) { viewModel.showNextMonth() }
            }
            MonthCalendarView(
                month: viewModel.shownMonth,
                states: viewModel.monthStates,
                today: viewModel.today,
                calendar: viewModel.calendar,
                locale: viewModel.locale
            )
            .accessibilityIdentifier(AccessibilityID.streakCalendar)
        }
    }

    private func monthButton(
        _ symbol: String,
        label: String,
        isEnabled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette(colorScheme).textPrimaryColor)
        .opacity(isEnabled ? 1 : 0.3)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func failed(palette: Palette) -> some View {
        let pair = palette.tone(.neutral)
        return VStack(alignment: .leading, spacing: 12) {
            Text(StreakCopy.loadFailed)
                .font(.body)
                .foregroundStyle(pair.foregroundColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(pair.backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button("Try again") { Task { await viewModel.load() } }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}

#if DEBUG
/// Fake logs for the previews: UTC, Monday first, and a clock fixed on a Wednesday.
private enum StreakPreviewLogs {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    static let locale = Locale(identifier: "en_US")
    static let now = Date(timeIntervalSince1970: 1_792_000_000)

    /// A 16 day chain ending today with the goal met on every third day, and one older chain in the
    /// previous month so the calendar has somewhere to page back to.
    static func log() -> PracticeLog {
        let day: TimeInterval = 86_400
        var sessions: [PracticeSession] = []
        for offset in 0..<16 {
            let finished = now.addingTimeInterval(-Double(offset) * day)
            sessions.append(PracticeSession(finishedAt: finished, answered: 10))
            if offset % 3 == 1 {
                sessions.append(PracticeSession(finishedAt: finished.addingTimeInterval(-600), answered: 10))
            }
        }
        sessions.append(PracticeSession(finishedAt: now.addingTimeInterval(-40 * day), answered: 8))
        return PracticeLog(sessions: sessions)
    }

    @MainActor
    static func model(_ log: PracticeLog) -> StreakViewModel {
        let fixed = now
        return StreakViewModel(
            practiceLog: InMemoryPracticeLogStore(initial: log),
            calendar: calendar,
            now: { fixed },
            locale: locale
        )
    }
}

#Preview("Streak screen, light") {
    StreakView(viewModel: StreakPreviewLogs.model(StreakPreviewLogs.log()), onDone: {})
        .preferredColorScheme(.light)
}

#Preview("Streak screen, dark") {
    StreakView(viewModel: StreakPreviewLogs.model(StreakPreviewLogs.log()), onDone: {})
        .preferredColorScheme(.dark)
}

#Preview("Streak screen, largest accessibility size") {
    StreakView(viewModel: StreakPreviewLogs.model(StreakPreviewLogs.log()), onDone: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Streak screen, no practice yet") {
    StreakView(viewModel: StreakPreviewLogs.model(.empty), onDone: {})
}
#endif
