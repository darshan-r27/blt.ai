import SwiftUI

/// A flame with the streak count: a small chip for Home, or a large centred flame for the streak screen.
///
/// - `isLit` is false while the learner has not yet practised in the current window: the flame is an outline
///   in muted colours instead of a filled amber one.
/// - Reads to VoiceOver as one element ("13 day streak, 1 freeze left"); the symbol is decoration.
/// - Reduce Motion: the symbol does not bounce and the number cross-fades instead of rolling.
/// - Callers add their own accessibility identifier (for example `AccessibilityID.homeStreakChip`).
public struct StreakFlameBadge: View {
    public enum Size: Sendable, Equatable {
        case small
        case large
    }

    private let count: Int
    private let size: Size
    private let freezesLeft: Int?
    private let isLit: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var largeFlameSide: Double = 72
    @ScaledMetric(relativeTo: .subheadline) private var chipFlameSide: Double = 18

    /// - Parameters:
    ///   - count: streak days; negative values show as 0.
    ///   - freezesLeft: when given, VoiceOver adds "1 freeze left" (the freezes themselves are drawn elsewhere).
    ///   - isLit: false draws an outline flame in muted colours (nothing finished in the current window yet).
    public init(count: Int, size: Size = .small, freezesLeft: Int? = nil, isLit: Bool = true) {
        self.count = max(count, 0)
        self.size = size
        self.freezesLeft = freezesLeft
        self.isLit = isLit
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        Group {
            switch size {
            case .small: chip(palette: palette)
            case .large: large(palette: palette)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StreakLabels.streak(count: count, freezesLeft: freezesLeft))
    }

    private func chip(palette: Palette) -> some View {
        HStack(spacing: 5) {
            flame(palette: palette)
                .frame(width: chipFlameSide, height: chipFlameSide)
            countText
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(isLit ? palette.flame.foregroundColor : palette.textSecondaryColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isLit ? palette.flame.backgroundColor : palette.surfaceColor, in: Capsule())
        .overlay(Capsule().strokeBorder(isLit ? palette.flame.glyphColor : palette.outlineColor, lineWidth: 1))
        .fixedSize()
    }

    private func large(palette: Palette) -> some View {
        VStack(spacing: 6) {
            flame(palette: palette)
                .frame(width: largeFlameSide, height: largeFlameSide)
            countText
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(palette.textPrimaryColor)
            Text("day streak")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
                .multilineTextAlignment(.center)
        }
    }

    private func flame(palette: Palette) -> some View {
        Image(systemName: isLit ? "flame.fill" : "flame")
            .resizable()
            .scaledToFit()
            .foregroundStyle(isLit ? palette.flame.glyphColor : palette.textSecondaryColor)
            // A constant value under Reduce Motion means the bounce never fires.
            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? 0 : count)
            .accessibilityHidden(true)
    }

    private var countText: some View {
        Text("\(count)")
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .snappy, value: count)
    }
}

#Preview("Flame badge, light") {
    StreakFlameBadgePreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Flame badge, dark") {
    StreakFlameBadgePreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Flame badge, largest accessibility size") {
    StreakFlameBadgePreviewSample()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct StreakFlameBadgePreviewSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                StreakFlameBadge(count: 13, freezesLeft: 1)
                StreakFlameBadge(count: 0, isLit: false)
                StreakFlameBadge(count: 128, isLit: false)
            }
            StreakFlameBadge(count: 13, size: .large, freezesLeft: 1)
                .frame(maxWidth: .infinity)
            StreakFlameBadge(count: 0, size: .large, isLit: false)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .bltScreenBackground()
    }
}
