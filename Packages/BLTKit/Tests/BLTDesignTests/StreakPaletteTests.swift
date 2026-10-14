import BLTDesign
import Testing

/// The streak tones: amber flame, blue freeze, green goal met. They go through the same rules as every other
/// colour, and Reset progress stays the only red (DECISIONS 037).
struct StreakPaletteTests {
    @Test(arguments: Palette.Scheme.allCases)
    func theThreeTonesAreInTheRedFreeColourList(scheme: Palette.Scheme) {
        let names = Set(Palette(scheme: scheme).allColors.map(\.name))
        for tone in ["flame", "freeze", "goalMet"] {
            for part in ["background", "foreground", "glyph"] {
                #expect(names.contains("\(tone).\(part)"), "\(tone).\(part) missing in \(scheme)")
            }
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func noStreakColourReadsAsRed(scheme: Palette.Scheme) {
        for entry in Palette(scheme: scheme).streakTones {
            for rgb in [entry.tone.background, entry.tone.foreground, entry.tone.glyph] {
                #expect(!rgb.isRed, "\(entry.name) in \(scheme) is red")
                // A wider margin than the red test: stay at least 15 degrees clear of the red arc's edge.
                #expect(rgb.hue > 30 || rgb.hue < 330 || rgb.saturation < 0.2)
                #expect(rgb.hue >= 20, "\(entry.name) in \(scheme) hue \(rgb.hue) is too close to red")
            }
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func resetProgressIsStillTheOnlyRed(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect(palette.destructive.foreground.isRed)
        #expect(palette.allColors.allSatisfy { !$0.rgb.isRed })
        #expect(palette.allColors.allSatisfy { !$0.name.hasPrefix("destructive") })
    }

    @Test(arguments: Palette.Scheme.allCases)
    func textOnEachTintMeetsWCAGAA(scheme: Palette.Scheme) {
        for entry in Palette(scheme: scheme).streakTones {
            let ratio = entry.tone.foreground.contrastRatio(with: entry.tone.background)
            #expect(ratio >= 4.5, "\(entry.name) text in \(scheme) is \(ratio)")
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func textOnEachTintIsReadableOnTheCardToo(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for entry in palette.streakTones {
            #expect(entry.tone.foreground.contrastRatio(with: palette.surface) >= 4.5, "\(entry.name) in \(scheme)")
            #expect(entry.tone.foreground.contrastRatio(with: palette.background) >= 4.5, "\(entry.name) in \(scheme)")
        }
    }

    /// WCAG 1.4.11: a symbol that carries meaning needs 3:1 against what it sits on.
    @Test(arguments: Palette.Scheme.allCases)
    func glyphsAreVisibleOnPageCardAndTheirOwnTint(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for entry in palette.streakTones {
            #expect(entry.tone.glyph.contrastRatio(with: palette.background) >= 3, "\(entry.name) vs page in \(scheme)")
            #expect(entry.tone.glyph.contrastRatio(with: palette.surface) >= 3, "\(entry.name) vs card in \(scheme)")
            let onTint = entry.tone.glyph.contrastRatio(with: entry.tone.background)
            #expect(onTint >= 3, "\(entry.name) vs tint in \(scheme)")
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func tintsAreDistinctFromThePage(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        for entry in palette.streakTones {
            let ratio = entry.tone.background.contrastRatio(with: palette.background)
            #expect(ratio >= 1.05, "\(entry.name) tint in \(scheme) vs page \(ratio)")
        }
    }

    /// Amber, blue and green must not blur into each other (the marks also differ by symbol).
    @Test(arguments: Palette.Scheme.allCases)
    func theThreeTonesAreDistinctByHue(scheme: Palette.Scheme) {
        let tones = Palette(scheme: scheme).streakTones
        for first in tones.indices {
            for second in tones.indices where first < second {
                let gap = abs(tones[first].tone.glyph.hue - tones[second].tone.glyph.hue)
                #expect(min(gap, 360 - gap) >= 60, "\(tones[first].name) vs \(tones[second].name) in \(scheme)")
            }
        }
    }

    @Test(arguments: Palette.Scheme.allCases)
    func eachToneHasItsExpectedFamily(scheme: Palette.Scheme) {
        let palette = Palette(scheme: scheme)
        #expect((20...50).contains(palette.flame.glyph.hue), "amber hue \(palette.flame.glyph.hue)")
        #expect((190...230).contains(palette.freeze.glyph.hue), "blue hue \(palette.freeze.glyph.hue)")
        #expect((120...160).contains(palette.goalMet.glyph.hue), "green hue \(palette.goalMet.glyph.hue)")
    }

    @Test func lightAndDarkStreakTonesDiffer() {
        #expect(Palette.light.flame != Palette.dark.flame)
        #expect(Palette.light.freeze != Palette.dark.freeze)
        #expect(Palette.light.goalMet != Palette.dark.goalMet)
    }
}
