import SwiftUI

/// The round mark for one day: an outline for an empty day, a flame, a snowflake, or a flame with a green
/// check. The state is carried by the symbol as well as the colour. Decorative: the cell around it carries the
/// VoiceOver label, so the whole mark is hidden from VoiceOver.
struct StreakDayMarker: View {
    let state: StreakDayState
    let isToday: Bool
    let isFuture: Bool
    /// The smaller size is used inside the month calendar.
    let isCompact: Bool

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var regularDiameter: Double = 34
    @ScaledMetric(relativeTo: .caption) private var compactDiameter: Double = 26

    private var diameter: Double { isCompact ? compactDiameter : regularDiameter }

    var body: some View {
        let palette = Palette(colorScheme)
        let tone = tone(in: palette)
        ZStack {
            Circle().fill(tone?.backgroundColor ?? .clear)
            Circle().strokeBorder(strokeColor(palette: palette, tone: tone), lineWidth: isToday ? 2.5 : 1)
            if let symbol, let tone {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tone.glyphColor)
                    .padding(diameter * 0.24)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .bottomTrailing) {
            if state == .goalMet, !isFuture {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(palette.goalMet.glyphColor)
                    .frame(width: diameter * 0.45, height: diameter * 0.45)
                    .background(palette.surfaceColor, in: Circle())
                    .offset(x: diameter * 0.12, y: diameter * 0.12)
            }
        }
        .accessibilityHidden(true)
    }

    private var symbol: String? {
        guard !isFuture else { return nil }
        switch state {
        case .empty: return nil
        case .practised, .goalMet: return "flame.fill"
        case .freeze: return "snowflake"
        }
    }

    /// A day still to come is always drawn empty, whatever state it was given.
    private func tone(in palette: Palette) -> Palette.StreakTone? {
        guard !isFuture else { return nil }
        switch state {
        case .empty: return nil
        case .practised, .goalMet: return palette.flame
        case .freeze: return palette.freeze
        }
    }

    private func strokeColor(palette: Palette, tone: Palette.StreakTone?) -> Color {
        if isToday { return palette.accentColor }
        return tone?.glyphColor ?? palette.outlineColor
    }
}
