import BLTDesign
import SwiftUI
import Testing

/// The shimmering greeting must stay readable at every point of its gradient and highlight.
struct ShimmerTextTests {
    private func mix(_ first: DesignRGB, _ second: DesignRGB, _ fraction: Double) -> DesignRGB {
        DesignRGB(
            red: first.red + (second.red - first.red) * fraction,
            green: first.green + (second.green - first.green) * fraction,
            blue: first.blue + (second.blue - first.blue) * fraction
        )
    }

    @Test(arguments: Palette.Scheme.allCases)
    func everyGradientStopAndTheHighlightPeakMeetWCAGAAOnThePage(scheme: Palette.Scheme) {
        let page = Palette(scheme: scheme).background
        let colors = ShimmerText.Colors.forScheme(scheme)
        #expect(colors.base.count >= 2)
        for (index, stop) in colors.allStops.enumerated() {
            let ratio = stop.contrastRatio(with: page)
            #expect(ratio >= 4.5, "stop \(index) in \(scheme) is \(ratio)")
        }
    }

    /// While the highlight fades in and out, glyph pixels are a blend of a base stop and the peak.
    @Test(arguments: Palette.Scheme.allCases)
    func everyBlendBetweenABaseStopAndThePeakMeetsWCAGAA(scheme: Palette.Scheme) {
        let page = Palette(scheme: scheme).background
        let colors = ShimmerText.Colors.forScheme(scheme)
        for stop in colors.base {
            for step in 0...20 {
                let blended = mix(stop, colors.highlightPeak, Double(step) / 20)
                let ratio = blended.contrastRatio(with: page)
                #expect(ratio >= 4.5, "blend \(step)/20 in \(scheme) is \(ratio)")
            }
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func highlightPeakIsVisiblyDifferentFromTheBase(scheme: Palette.Scheme) {
        let colors = ShimmerText.Colors.forScheme(scheme)
        for stop in colors.base {
            #expect(stop != colors.highlightPeak)
        }
        let darkest = colors.base.map(\.relativeLuminance).min() ?? 0
        let lightest = colors.base.map(\.relativeLuminance).max() ?? 0
        #expect(lightest > darkest)
    }

    @Test(arguments: Palette.Scheme.allCases)
    func shimmerColoursArePurplesNotRed(scheme: Palette.Scheme) {
        for stop in ShimmerText.Colors.forScheme(scheme).allStops {
            let outsideRedArc = stop.hue < 345 && stop.hue > 15
            #expect(outsideRedArc || stop.saturation < 0.2)
            #expect(stop.blue > stop.green, "purple has more blue than green")
        }
    }

    @MainActor
    @Test func isAViewTakingPlainTextAndAFont() {
        let view = ShimmerText("zz Hi", font: .title)
        #expect(String(describing: type(of: view)).contains("ShimmerText"))
    }
}
