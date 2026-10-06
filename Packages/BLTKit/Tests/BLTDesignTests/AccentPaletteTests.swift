import BLTDesign
import Testing

/// The deep-purple accent (owner decision, U5): exact values and the contrast they must keep.
struct AccentPaletteTests {
    @Test func accentValuesAreTheOwnersExactHexes() {
        #expect(Palette.light.accent == DesignRGB(hex: 0x5B3FA8))
        #expect(Palette.light.onAccent == DesignRGB(hex: 0xFFFFFF))
        #expect(Palette.light.accentTint == DesignRGB(hex: 0xE4DBF6))
        #expect(Palette.dark.accent == DesignRGB(hex: 0xB79CF0))
        #expect(Palette.dark.onAccent == DesignRGB(hex: 0x1A1821))
        #expect(Palette.dark.accentTint == DesignRGB(hex: 0x33294F))
    }

    @Test func pageBackgroundsAreUnchanged() {
        #expect(Palette.light.background == DesignRGB(hex: 0xF0EAFA))
        #expect(Palette.dark.background == DesignRGB(hex: 0x1A1821))
    }

    @Test(arguments: Palette.Scheme.allCases)
    func labelOnAccentMeetsWCAGAA(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let ratio = palette.onAccent.contrastRatio(with: palette.accent)
        #expect(ratio >= 4.5, "onAccent on accent in \(scheme) is \(ratio)")
    }

    /// WCAG 1.4.11: the button's fill must stand out from the page behind it.
    @Test(arguments: Palette.Scheme.allCases)
    func accentIsAVisibleComponentAgainstPageAndCard(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.accent.contrastRatio(with: palette.background) >= 3, "accent vs page in \(scheme)")
        #expect(palette.accent.contrastRatio(with: palette.surface) >= 3, "accent vs card in \(scheme)")
    }

    /// Tinted links and bordered-button labels are text drawn in the accent on the page or a card.
    @Test(arguments: Palette.Scheme.allCases)
    func accentAsLinkTextMeetsWCAGAA(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let onPage = palette.accent.contrastRatio(with: palette.background)
        let onCard = palette.accent.contrastRatio(with: palette.surface)
        #expect(onPage >= 4.5, "accent text on page in \(scheme) is \(onPage)")
        #expect(onCard >= 4.5, "accent text on card in \(scheme) is \(onCard)")
    }

    @Test(arguments: Palette.Scheme.allCases)
    func accentTextIsReadableOnTheAccentTint(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.accent.contrastRatio(with: palette.accentTint) >= 4.5)
        #expect(palette.textPrimary.contrastRatio(with: palette.accentTint) >= 4.5)
    }

    @Test(arguments: Palette.Scheme.allCases)
    func accentTintIsDistinctFromThePage(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        let ratio = palette.accentTint.contrastRatio(with: palette.background)
        #expect(ratio >= 1.05, "accentTint vs page in \(scheme) is \(ratio)")
    }

    /// The tint must not be mistaken for a feedback tone: it differs in hue from every tone background.
    @Test(arguments: Palette.Scheme.allCases)
    func accentTintIsDistinctFromToneBackgrounds(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for tone in [FeedbackTone.affirm, .nudge, .neutral] {
            let toneBackground = palette.tone(tone).background
            #expect(palette.accentTint != toneBackground)
            let gap = abs(palette.accentTint.hue - toneBackground.hue)
            #expect(min(gap, 360 - gap) >= 30, "accentTint vs \(tone) in \(scheme): hue gap \(min(gap, 360 - gap))")
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func accentColoursAreNotRed(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for rgb in [palette.accent, palette.onAccent, palette.accentTint] {
            let outsideRedArc = rgb.hue < 345 && rgb.hue > 15
            #expect(outsideRedArc || rgb.saturation < 0.2)
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func accentColoursAreInAllColors(scheme: Palette.Scheme) {
        let names = Set(Palette(scheme: scheme).allColors.map(\.name))
        #expect(names.isSuperset(of: ["accent", "onAccent", "accentTint"]))
    }
}
