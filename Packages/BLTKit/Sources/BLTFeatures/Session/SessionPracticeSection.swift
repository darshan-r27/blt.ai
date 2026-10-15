import BLTDesign
import SwiftUI

/// The daily-practice part of the end-of-session summary: the flame (a burst when the streak grew, quiet when
/// it did not, bigger at 7, 30, 50 and 100 days), "Daily goal met" in green when the day's second chapter has
/// just finished, the week strip with today filled in, and the days to the next freeze. Never red. With
/// Reduce Motion the count fades in instead (`StreakCelebrationView` handles that).
struct SessionPracticeSection: View {
    let state: PracticeRecordState
    let calendar: Calendar
    var locale: Locale = .current

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch state {
        case .none:
            EmptyView()
        case .recorded(let outcome):
            recorded(outcome)
        case .failed:
            failedNotice
        }
    }

    private func recorded(_ outcome: PracticeOutcome) -> some View {
        let palette = Palette(colorScheme)
        return VStack(spacing: 16) {
            StreakCelebrationView(
                previousCount: outcome.previousCount,
                count: outcome.newCount,
                freezesLeft: outcome.freezesLeft
            )
            .accessibilityIdentifier(AccessibilityID.sessionStreak)

            goalLine(outcome, palette: palette)

            WeekStripView(
                days: StreakWeek.days(
                    containing: outcome.finishedAt,
                    states: StreakDayStates.states(for: outcome.summary, calendar: calendar),
                    calendar: calendar
                ),
                today: outcome.finishedAt,
                calendar: calendar,
                locale: locale
            )
            .accessibilityIdentifier(AccessibilityID.sessionWeekStrip)

            Label {
                Text(StreakCopy.nextFreeze(daysUntil: outcome.daysUntilNextFreeze))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "snowflake")
                    .font(.subheadline)
                    .foregroundStyle(palette.freeze.glyphColor)
            }
            .foregroundStyle(palette.textSecondaryColor)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.sessionNextFreeze)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func goalLine(_ outcome: PracticeOutcome, palette: Palette) -> some View {
        if outcome.goalJustMet {
            Label {
                Text(StreakCopy.dailyGoalMet)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
            }
            .foregroundStyle(palette.goalMet.foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.goalMet.backgroundColor, in: Capsule())
            .overlay(Capsule().strokeBorder(palette.goalMet.glyphColor, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.sessionGoalMet)
        } else {
            Text(StreakLabels.today(chaptersDone: outcome.chaptersToday, goal: outcome.dailyGoal))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failedNotice: some View {
        let pair = Palette(colorScheme).tone(.neutral)
        return Label {
            Text(StreakCopy.logNotUpdated)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "info.circle")
                .font(.footnote)
        }
        .foregroundStyle(pair.foregroundColor)
        .padding(14)
        .background(pair.backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
import BLTProgress
import BLTSession

/// Fake logs for the previews: a calendar and a clock fixed in UTC, and a daily chain ending today.
private enum PracticePreview {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    static let now = Date(timeIntervalSince1970: 1_792_000_000)

    /// One session a day for `streakDays - 1` days before today, plus `chaptersToday` sessions today.
    static func outcome(streakDays: Int, chaptersToday: Int) -> PracticeOutcome {
        let day: TimeInterval = 86_400
        let earlier = (1..<max(streakDays, 1)).map {
            PracticeSession(finishedAt: now.addingTimeInterval(-Double($0) * day), answered: 10)
        }
        let today = (0..<chaptersToday).map {
            PracticeSession(finishedAt: now.addingTimeInterval(-Double($0) * 600), answered: 10)
        }
        let all = PracticeLog(sessions: earlier + today)
        let last = today.min { $0.finishedAt < $1.finishedAt }
        let before = PracticeLog(sessions: all.sessions.filter { $0 != last })
        let calculator = StreakCalculator()
        return PracticeOutcome(
            finishedAt: now,
            before: calculator.summary(for: before, now: now, calendar: calendar),
            after: calculator.summary(for: all, now: now, calendar: calendar)
        )
    }

    static let result = SessionResult(correctCount: 6, wrongRegisterCount: 2, wrongCount: 2)
}

#Preview("Summary, first chapter of the day (burst), light") {
    SessionSummaryView(
        result: PracticePreview.result,
        practice: .recorded(PracticePreview.outcome(streakDays: 13, chaptersToday: 1)),
        calendar: PracticePreview.calendar,
        onDone: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Summary, second chapter (daily goal met), light") {
    SessionSummaryView(
        result: PracticePreview.result,
        practice: .recorded(PracticePreview.outcome(streakDays: 13, chaptersToday: 2)),
        calendar: PracticePreview.calendar,
        onDone: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Summary at a 7 day milestone, dark") {
    SessionSummaryView(
        result: PracticePreview.result,
        practice: .recorded(PracticePreview.outcome(streakDays: 7, chaptersToday: 1)),
        calendar: PracticePreview.calendar,
        onDone: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Summary, third chapter (quiet)") {
    SessionSummaryView(
        result: PracticePreview.result,
        practice: .recorded(PracticePreview.outcome(streakDays: 5, chaptersToday: 3)),
        calendar: PracticePreview.calendar,
        onDone: {}
    )
}

#Preview("Summary, streak log failed") {
    SessionSummaryView(result: PracticePreview.result, practice: .failed, onDone: {})
}

#Preview("Summary with streak, largest accessibility size") {
    SessionSummaryView(
        result: PracticePreview.result,
        practice: .recorded(PracticePreview.outcome(streakDays: 30, chaptersToday: 2)),
        calendar: PracticePreview.calendar,
        onDone: {}
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
