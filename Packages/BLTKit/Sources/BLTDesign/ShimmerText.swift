import SwiftUI

/// Text with a deep-purple gradient fill and a soft highlight that sweeps across it every few
/// seconds, so a hero line (the Home greeting) looks polished without being noisy.
///
/// Rules, each enforced by `ShimmerTextTests`:
/// - every gradient stop, the highlight peak and every blend between the two keeps at least 4.5:1
///   against the page background in light and dark;
/// - with Reduce Motion on, the gradient is static and nothing animates;
/// - the sweeping highlight is decoration only (`accessibilityHidden`); the text keeps the heading
///   trait, and callers add their own accessibility identifier.
///
/// Uses a text style by default, so it follows Dynamic Type and wraps rather than truncating.
public struct ShimmerText: View {
    /// The colours for one colour scheme. Hexes are chosen against the page backgrounds
    /// `#F0EAFA` (light) and `#1A1821` (dark).
    public struct Colors: Sendable, Equatable {
        /// Gradient stops from leading to trailing.
        public let base: [DesignRGB]
        /// The colour at the centre of the moving highlight.
        public let highlightPeak: DesignRGB

        /// Every colour that can appear in the fill: the base stops and the highlight peak.
        public var allStops: [DesignRGB] { base + [highlightPeak] }

        public static func forScheme(_ scheme: Palette.Scheme) -> Colors {
            switch scheme {
            case .light:
                Colors(
                    base: [DesignRGB(hex: 0x45308F), DesignRGB(hex: 0x5B3FA8), DesignRGB(hex: 0x6C4DBA)],
                    highlightPeak: DesignRGB(hex: 0x7050C2)
                )
            case .dark:
                Colors(
                    base: [DesignRGB(hex: 0xB79CF0), DesignRGB(hex: 0xC8B0FA), DesignRGB(hex: 0xD9C8FF)],
                    highlightPeak: DesignRGB(hex: 0xF2EBFF)
                )
            }
        }
    }

    private let text: String
    private let font: Font

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = highlight just off the leading edge, 1 = just off the trailing edge.
    @State private var phase: Double = 0

    public init(_ text: String, font: Font = .largeTitle.bold()) {
        self.text = text
        self.font = font
    }

    public var body: some View {
        let colors = Colors.forScheme(Palette.Scheme(colorScheme))
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(colors: colors.base.map(\.color), startPoint: .leading, endPoint: .trailing)
            )
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .overlay {
                if !reduceMotion {
                    highlight(peak: colors.highlightPeak)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityAddTraits(.isHeader)
            .task(id: reduceMotion) { await runShimmer() }
    }

    /// A soft band of the peak colour, clipped to the glyphs by masking with the same text.
    private func highlight(peak: DesignRGB) -> some View {
        GeometryReader { proxy in
            let bandWidth = proxy.size.width * 0.45
            let travel = proxy.size.width + bandWidth
            LinearGradient(
                colors: [peak.color.opacity(0), peak.color, peak.color.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: bandWidth)
            .offset(x: -bandWidth + travel * phase)
        }
        .mask(alignment: .topLeading) {
            Text(text)
                .font(font)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Rests, sweeps once, snaps back unseen, repeats. Cancelled with the view or when Reduce Motion
    /// turns on (the task id changes), which also parks the highlight off-screen.
    private func runShimmer() async {
        phase = 0
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(4))
                withAnimation(.easeInOut(duration: 1.4)) { phase = 1 }
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { phase = 0 }
        }
    }
}

#Preview("Shimmer text, light") {
    ShimmerTextPreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Shimmer text, dark") {
    ShimmerTextPreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Shimmer text, largest accessibility size") {
    ShimmerTextPreviewSample()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct ShimmerTextPreviewSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShimmerText("Hi zz Sample")
            ShimmerText("Hi zz A rather long sample name that has to wrap")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .bltScreenBackground()
    }
}
