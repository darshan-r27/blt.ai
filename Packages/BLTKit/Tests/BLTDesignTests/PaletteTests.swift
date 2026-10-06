import BLTCore
import BLTDesign
import Testing

struct PaletteTests {
    private let allTones: [FeedbackTone] = [.affirm, .nudge, .neutral]

    @Test(arguments: Palette.Scheme.allCases)
    func noPaletteColourIsRed(scheme: Palette.Scheme) {
        for entry in Palette(scheme: scheme).allColors {
            let outsideRedArc = entry.rgb.hue < 345 && entry.rgb.hue > 15
            #expect(outsideRedArc || entry.rgb.saturation < 0.2, "\(entry.name) in \(scheme) is red-ish")
            #expect(!entry.rgb.isRed)
        }
    }

    @Test func redDetectorFlagsRedAndAllowsGrey() {
        #expect(DesignRGB(hex: 0xFF0000).isRed)
        #expect(DesignRGB(hex: 0xD03050).isRed)
        #expect(!DesignRGB(hex: 0x808080).isRed)
        #expect(!DesignRGB(hex: 0x00AA00).isRed)
    }

    @Test(arguments: Palette.Scheme.allCases)
    func everyTonePairMeetsWCAGAA(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for tone in allTones {
            let pair = palette.tone(tone)
            let ratio = pair.foreground.contrastRatio(with: pair.background)
            #expect(ratio >= 4.5, "\(tone) in \(scheme) has contrast \(ratio)")
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func bodyTextMeetsWCAGAAOnSurfaceAndBackground(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for text in [palette.textPrimary, palette.textSecondary] {
            #expect(text.contrastRatio(with: palette.surface) >= 4.5)
            #expect(text.contrastRatio(with: palette.background) >= 4.5)
        }
    }

    @Test func contrastRatioMatchesKnownValues() {
        let black = DesignRGB(hex: 0x000000)
        let white = DesignRGB(hex: 0xFFFFFF)
        #expect(abs(black.contrastRatio(with: white) - 21) < 0.001)
        #expect(abs(white.contrastRatio(with: black) - 21) < 0.001)
        #expect(abs(white.contrastRatio(with: white) - 1) < 0.001)
    }

    @Test(arguments: Palette.Scheme.allCases)
    func tonesAreDistinct(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let pairs = allTones.map { palette.tone($0) }
        for first in pairs.indices {
            for second in pairs.indices where first < second {
                #expect(pairs[first].background != pairs[second].background)
                #expect(pairs[first].foreground != pairs[second].foreground)
                // Distinct by hue too, not just by a slightly different shade.
                let gap = abs(pairs[first].background.hue - pairs[second].background.hue)
                #expect(min(gap, 360 - gap) >= 30)
            }
        }
    }

    @Test func lightAndDarkDiffer() {
        #expect(Palette.light != Palette.dark)
        #expect(Palette.light.background != Palette.dark.background)
    }

    @Test func paletteIsDeterministic() {
        for scheme in Palette.Scheme.allCases {
            #expect(Palette(scheme: scheme) == Palette(scheme: scheme))
            #expect(Palette(scheme: scheme).allColors.map(\.rgb) == Palette(scheme: scheme).allColors.map(\.rgb))
        }
        #expect(Palette.light == Palette(scheme: .light))
        #expect(Palette.dark == Palette(scheme: .dark))
    }
}
