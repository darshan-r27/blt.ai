import BLTDesign
import SwiftUI

/// The top of Home: the flame chip, the Today card, and this week's strip with the freezes left. If the practice
/// log could not be read it shows one calm note instead; the lessons below are unaffected.
struct HomePracticeSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HomeViewModel
    let onStartChapter: () -> Void
    let onOpenStreak: () -> Void

    var body: some View {
        if viewModel.practiceError != nil {
            note
        } else {
            VStack(alignment: .leading, spacing: 12) {
                chip
                TodayCardView(card: viewModel.todayCard, action: onStartChapter)
                weekCard
            }
        }
    }

    private var chip: some View {
        Button(action: onOpenStreak) {
            StreakFlameBadge(
                count: viewModel.streakCount,
                freezesLeft: viewModel.practiceSummary.freezesAvailable,
                isLit: viewModel.isStreakLit
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your streak")
        .accessibilityIdentifier(AccessibilityID.homeStreakChip)
    }

    private var weekCard: some View {
        let palette = Palette(colorScheme)
        return VStack(alignment: .leading, spacing: 10) {
            WeekStripView(
                days: viewModel.weekDays,
                today: viewModel.currentTime,
                calendar: viewModel.practiceCalendar
            )
            .accessibilityIdentifier(AccessibilityID.homeWeekStrip)
            Text(viewModel.freezeLine)
                .font(.subheadline)
                .foregroundStyle(palette.freeze.foregroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14))
    }

    private var note: some View {
        let palette = Palette(colorScheme)
        return Text(HomeViewModel.practiceUnreadableNote)
            .font(.subheadline)
            .foregroundStyle(palette.nudge.foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.nudge.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }
}
