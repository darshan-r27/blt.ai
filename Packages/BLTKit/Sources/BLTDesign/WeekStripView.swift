import SwiftUI

/// The seven days of a week as marks: flame, snowflake, flame with a green check, or an empty outline.
/// Today has an accent ring; days still to come are drawn empty.
///
/// - Each day is one VoiceOver element ("Tuesday, October 13, today, practised, streak day"); the strip is a
///   container labelled "This week". Letters and marks are decoration.
/// - At accessibility text sizes the seven columns would not fit, so the strip becomes a list of rows.
/// - Each day carries `AccessibilityID.weekStripDay(_:)`; callers set the strip's own id
///   (`homeWeekStrip`, `sessionWeekStrip`) on the whole view.
public struct WeekStripView: View {
    private let days: [StreakDay]
    private let today: Date
    private let calendar: Calendar
    private let locale: Locale

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - days: usually the seven days from `StreakWeek.days(containing:states:calendar:)`.
    ///   - today: the current date; marks today and tells future days from past ones.
    public init(days: [StreakDay], today: Date, calendar: Calendar = .current, locale: Locale = .current) {
        self.days = days
        self.today = today
        self.calendar = calendar
        self.locale = locale
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        row(day, index: index)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        column(day, index: index)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StreakLabels.week)
    }

    private func column(_ day: StreakDay, index: Int) -> some View {
        let palette = Palette(colorScheme)
        let isToday = calendar.isDate(day.date, inSameDayAs: today)
        return VStack(spacing: 6) {
            Text(letter(for: day.date))
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? palette.textPrimaryColor : palette.textSecondaryColor)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            marker(day, isToday: isToday)
        }
        .frame(maxWidth: .infinity)
        .modifier(DayAccessibility(label: label(for: day), index: index))
    }

    private func row(_ day: StreakDay, index: Int) -> some View {
        let palette = Palette(colorScheme)
        let isToday = calendar.isDate(day.date, inSameDayAs: today)
        let isFuture = StreakWeek.isFuture(day.date, today: today, calendar: calendar)
        return HStack(spacing: 12) {
            marker(day, isToday: isToday)
            VStack(alignment: .leading, spacing: 2) {
                Text(StreakLabels.dayName(day.date, calendar: calendar, locale: locale))
                    .font(.body.weight(isToday ? .bold : .regular))
                    .foregroundStyle(palette.textPrimaryColor)
                Text(StreakLabels.state(day.state, isFuture: isFuture))
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .modifier(DayAccessibility(label: label(for: day), index: index))
    }

    private func marker(_ day: StreakDay, isToday: Bool) -> some View {
        StreakDayMarker(
            state: day.state,
            isToday: isToday,
            isFuture: StreakWeek.isFuture(day.date, today: today, calendar: calendar),
            isCompact: false
        )
    }

    private func label(for day: StreakDay) -> String {
        StreakLabels.day(date: day.date, state: day.state, today: today, calendar: calendar, locale: locale)
    }

    private func letter(for date: Date) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}

/// Makes one day a single VoiceOver element with its own identifier.
private struct DayAccessibility: ViewModifier {
    let label: String
    let index: Int

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityIdentifier(AccessibilityID.weekStripDay(index))
    }
}

#if DEBUG
#Preview("Week strip, light") {
    WeekStripPreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Week strip, dark") {
    WeekStripPreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Week strip, largest accessibility size") {
    WeekStripPreviewSample()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct WeekStripPreviewSample: View {
    var body: some View {
        let calendar = StreakPreviewData.calendar
        let today = StreakPreviewData.today
        let days = StreakWeek.days(containing: today, states: StreakPreviewData.states, calendar: calendar)
        WeekStripView(days: days, today: today, calendar: calendar, locale: StreakPreviewData.locale)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .bltScreenBackground()
    }
}
#endif
