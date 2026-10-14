import SwiftUI

/// A month grid of day marks, with the same states as the week strip, a legend and a text summary.
///
/// - The first column is the calendar's first weekday (`MonthGrid` does the layout).
/// - Each day is one VoiceOver element ("Tuesday, October 13, today, practised, streak day"); blank cells,
///   weekday letters and the legend are hidden from VoiceOver. The month title is a heading and the summary
///   line ("12 practice days, 3 with the daily goal met") is plain text.
/// - Dynamic Type: the dense grid itself stops growing at the largest non-accessibility size, because seven
///   columns of two-digit numbers cannot fit beside each other at accessibility sizes. The title, legend and
///   summary keep growing and wrap, and the summary carries the month's information in words.
/// - Each day carries `AccessibilityID.streakCalendarDay(_:)`; callers set `AccessibilityID.streakCalendar`
///   on the whole view.
public struct MonthCalendarView: View {
    private let grid: MonthGrid
    private let month: Date
    private let states: [Date: StreakDayState]
    private let today: Date
    private let calendar: Calendar
    private let locale: Locale

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - month: any date inside the month to show.
    ///   - states: day states keyed by the start of the day in `calendar`; a missing day is empty.
    ///   - today: the current date; marks today and tells future days from past ones.
    public init(
        month: Date,
        states: [Date: StreakDayState],
        today: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) {
        self.grid = MonthGrid(month: month, calendar: calendar)
        self.month = month
        self.states = states
        self.today = today
        self.calendar = calendar
        self.locale = locale
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Text(StreakLabels.monthTitle(month, calendar: calendar, locale: locale))
                .font(.headline)
                .foregroundStyle(palette.textPrimaryColor)
                .accessibilityAddTraits(.isHeader)
            calendarGrid(palette: palette)
            legend(palette: palette)
            Text(StreakLabels.monthSummary(grid.summary(states: states)))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func calendarGrid(palette: Palette) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(MonthGrid.weekdayHeaders(calendar: calendar).enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondaryColor)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(grid.rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(row) { cell in
                        cellView(cell, palette: palette)
                    }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private func cellView(_ cell: MonthGrid.Cell, palette: Palette) -> some View {
        if let date = cell.date, let day = cell.day {
            let state = states[date] ?? .empty
            let isToday = calendar.isDate(date, inSameDayAs: today)
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.caption2.monospacedDigit().weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? palette.textPrimaryColor : palette.textSecondaryColor)
                StreakDayMarker(
                    state: state,
                    isToday: isToday,
                    isFuture: StreakWeek.isFuture(date, today: today, calendar: calendar),
                    isCompact: true
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                StreakLabels.day(date: date, state: state, today: today, calendar: calendar, locale: locale)
            )
            .accessibilityIdentifier(AccessibilityID.streakCalendarDay(day))
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    /// What the marks mean, for sighted readers. VoiceOver gets the same words from each day's label.
    private func legend(palette: Palette) -> some View {
        DesignWrappingLayout(horizontalSpacing: 16, verticalSpacing: 6) {
            legendItem("flame.fill", palette.flame.glyphColor, "Practised", palette: palette)
            legendItem("snowflake", palette.freeze.glyphColor, "Freeze used", palette: palette)
            legendItem("checkmark.circle.fill", palette.goalMet.glyphColor, "Daily goal met", palette: palette)
        }
        .accessibilityHidden(true)
    }

    private func legendItem(_ symbol: String, _ color: Color, _ text: String, palette: Palette) -> some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundStyle(palette.textSecondaryColor)
        } icon: {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(color)
        }
    }
}

#if DEBUG
#Preview("Month calendar, light") {
    MonthCalendarPreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Month calendar, dark") {
    MonthCalendarPreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Month calendar, largest accessibility size") {
    MonthCalendarPreviewSample()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct MonthCalendarPreviewSample: View {
    var body: some View {
        ScrollView {
            MonthCalendarView(
                month: StreakPreviewData.today,
                states: StreakPreviewData.states,
                today: StreakPreviewData.today,
                calendar: StreakPreviewData.calendar,
                locale: StreakPreviewData.locale
            )
            .padding()
        }
        .bltScreenBackground()
    }
}
#endif
