import BLTDesign
import BLTSession
import SwiftUI

/// End-of-session summary: three plain counts, the daily-practice streak moment (see
/// `SessionPracticeSection`) and a Done action. No scores and no praise inflation.
struct SessionSummaryView: View {
    let result: SessionResult
    var practice = PracticeRecordState.none
    var calendar = Calendar.current
    let onDone: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Session finished")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                SessionPracticeSection(state: practice, calendar: calendar)
                Text(
                    "You went through \(result.total) \(result.total == 1 ? "phrase" : "phrases"). "
                        + "Counts are for your first attempt at each one."
                )
                .font(.body)
                .foregroundStyle(palette.textSecondaryColor)

                VStack(spacing: 10) {
                    row("Correct", count: result.correctCount, tone: .affirm)
                    row("Right sentence, wrong register", count: result.wrongRegisterCount, tone: .nudge)
                    row("Not quite", count: result.wrongCount, tone: .neutral)
                }

                Button("Done", action: onDone)
                    .buttonStyle(.bltPrimary)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(palette.backgroundColor)
    }

    private func row(_ title: String, count: Int, tone: FeedbackTone) -> some View {
        let pair = Palette(colorScheme).tone(tone)
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .font(.title3.weight(.semibold))
        }
        .foregroundStyle(pair.foregroundColor)
        .padding(14)
        .background(pair.backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(count)")
    }
}
