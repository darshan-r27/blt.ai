import SwiftUI

/// A calm completion graphic: a capsule track in the accent tint, an accent fill, and a plain
/// percent label ("35%"). It reads to VoiceOver as one element: "Completion, 35 percent complete".
///
/// At 100% it shows a quiet check mark; nothing else changes (no confetti).
public struct CompletionBar: View {
    private let percent: Int

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var barHeight: Double = 10

    /// - Parameter percent: whole-number completion; values outside 0...100 are clamped.
    public init(percent: Int) {
        self.percent = Self.clamped(percent)
    }

    public nonisolated static func clamped(_ percent: Int) -> Int {
        min(max(percent, 0), 100)
    }

    /// The label drawn next to the bar, for example "35%".
    public nonisolated static func label(forPercent percent: Int) -> String {
        "\(clamped(percent))%"
    }

    /// What VoiceOver reads as the bar's value, for example "35 percent complete".
    public nonisolated static func accessibilityValue(forPercent percent: Int) -> String {
        "\(clamped(percent)) percent complete"
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        HStack(spacing: 10) {
            Capsule()
                .fill(palette.accentTintColor)
                .frame(height: barHeight)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(palette.accentColor)
                            .frame(width: fillWidth(in: proxy.size.width))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: percent)
                    }
                }
                .overlay(Capsule().strokeBorder(palette.outlineColor, lineWidth: 1))
            if percent == 100 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(palette.accentColor)
                    .accessibilityHidden(true)
            }
            Text(Self.label(forPercent: percent))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.textPrimaryColor)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion")
        .accessibilityValue(Self.accessibilityValue(forPercent: percent))
    }

    /// A non-zero fill is never narrower than the bar is tall, so it stays a visible dot.
    private func fillWidth(in trackWidth: Double) -> Double {
        guard percent > 0 else { return 0 }
        return max(barHeight, trackWidth * Double(percent) / 100)
    }
}

#Preview("Completion bar, light") {
    CompletionBarPreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Completion bar, dark") {
    CompletionBarPreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Completion bar, largest accessibility size") {
    CompletionBarPreviewSample()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct CompletionBarPreviewSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CompletionBar(percent: 0)
            CompletionBar(percent: 5)
            CompletionBar(percent: 35)
            CompletionBar(percent: 100)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .bltScreenBackground()
    }
}
