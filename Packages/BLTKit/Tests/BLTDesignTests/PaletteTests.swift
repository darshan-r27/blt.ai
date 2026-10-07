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

    /// The one deliberate red: Reset progress (DECISIONS 037). It must read as a warning and stay legible.
    @Test(arguments: Palette.Scheme.allCases)
    func destructivePairIsRedAndMeetsWCAGAA(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let pair = palette.destructive
        #expect(pair.foreground.isRed, "the warning text colour should be red in \(scheme)")
        #expect(pair.foreground.contrastRatio(with: pair.background) >= 4.5)
        // The outline is the foreground colour, so it must also stand out from the page itself.
        #expect(pair.foreground.contrastRatio(with: palette.background) >= 4.5)
        #expect(pair.foreground.contrastRatio(with: palette.surface) >= 4.5)
    }

    @Test func destructiveColoursAreNotPartOfTheRedFreePalette() {
        for scheme in Palette.Scheme.allCases {
            let names = Palette(scheme: scheme).allColors.map(\.name)
            #expect(!names.contains { $0.hasPrefix("destructive") })
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

    // MARK: Lilac page background

    @Test func lightBackgroundIsALightLilac() {
        let background = Palette.light.background
        #expect(background.hue >= 255 && background.hue <= 285, "hue \(background.hue)")
        #expect(background.saturation >= 0.05 && background.saturation <= 0.20, "saturation \(background.saturation)")
        #expect(background.relativeLuminance >= 0.8, "luminance \(background.relativeLuminance)")
        #expect(!background.isRed)
    }

    @Test func darkBackgroundIsADeepMutedPurpleGrey() {
        let background = Palette.dark.background
        #expect(background.hue >= 245 && background.hue <= 285, "hue \(background.hue)")
        #expect(background.saturation <= 0.35, "saturation \(background.saturation)")
        #expect(background.relativeLuminance <= 0.02, "luminance \(background.relativeLuminance)")
        #expect(Palette.dark.background.relativeLuminance < Palette.light.background.relativeLuminance)
    }

    @Test func lilacIsFarFromRed() {
        for scheme in Palette.Scheme.allCases {
            let hue = Palette(scheme: scheme).background.hue
            let distanceFromRed = min(hue, 360 - hue)
            #expect(distanceFromRed > 90, "\(scheme) background hue \(hue)")
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func surfaceIsASlightlyLighterCardOnThePage(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.surface.relativeLuminance > palette.background.relativeLuminance)
        let ratio = palette.surface.contrastRatio(with: palette.background)
        #expect(ratio >= 1.05 && ratio <= 1.3, "\(scheme) surface vs page \(ratio)")
    }

    @Test(arguments: Palette.Scheme.allCases)
    func outlineIsVisibleAgainstPageAndSurface(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.outline.contrastRatio(with: palette.background) >= 1.2)
        #expect(palette.outline.contrastRatio(with: palette.surface) >= 1.2)
    }

    /// Minimum contrast ratio between a tone's background and the page behind it, so a tinted
    /// panel never dissolves into the page. Tones also carry a border and a symbol (see `OptionButton`).
    private let minimumToneVersusPageContrast = 1.08

    @Test(arguments: Palette.Scheme.allCases)
    func everyToneBackgroundIsDistinctFromThePage(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for tone in allTones {
            let ratio = palette.tone(tone).background.contrastRatio(with: palette.background)
            #expect(ratio >= minimumToneVersusPageContrast, "\(tone) in \(scheme) vs page \(ratio)")
        }
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
