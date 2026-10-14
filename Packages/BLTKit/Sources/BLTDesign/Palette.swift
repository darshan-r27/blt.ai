import SwiftUI

/// Explicit light/dark palette. There is deliberately no red: feedback colour comes only from
/// `FeedbackTone`, and tones read as affirming (green), gentle (amber) and calm (blue-grey). The one
/// exception is `destructive`, used only for Reset progress so it always looks like a warning (DECISIONS 037);
/// it is kept out of `allColors`, which the no-red test covers.
/// The page background is a light lilac in light mode and a deep muted purple-grey in dark mode;
/// cards (`surface`) are a step lighter than the page in both. The app accent is a deep purple (a lighter
/// purple with dark text in dark mode); it fills primary buttons and tints links, toolbar icons and cursors.
/// Contrast (WCAG >= 4.5:1), tone-versus-page
/// distinctness and the no-red rule are enforced by `PaletteTests`.
public struct Palette: Sendable, Equatable {
    public enum Scheme: Sendable, Equatable, CaseIterable {
        case light
        case dark

        public init(_ colorScheme: ColorScheme) {
            self = colorScheme == .dark ? .dark : .light
        }
    }

    /// Text colour and its tinted background for one feedback tone.
    public struct TonePair: Sendable, Equatable {
        public let background: DesignRGB
        public let foreground: DesignRGB

        public var backgroundColor: Color { background.color }
        public var foregroundColor: Color { foreground.color }
    }

    /// Colours for one streak mark: a tinted background, text on it, and a brighter fill for the symbol itself.
    /// Used only for the streak visuals (flame, freeze, goal met). The symbol fill is a graphic, so it must reach
    /// 3:1 against the page, the card and its own tint; the text must reach 4.5:1 on the tint (`PaletteTests`).
    public struct StreakTone: Sendable, Equatable {
        public let background: DesignRGB
        public let foreground: DesignRGB
        public let glyph: DesignRGB

        init(background: UInt32, foreground: UInt32, glyph: UInt32) {
            self.background = DesignRGB(hex: background)
            self.foreground = DesignRGB(hex: foreground)
            self.glyph = DesignRGB(hex: glyph)
        }

        public var backgroundColor: Color { background.color }
        public var foregroundColor: Color { foreground.color }
        public var glyphColor: Color { glyph.color }
    }

    public let scheme: Scheme

    public let background: DesignRGB
    public let surface: DesignRGB
    public let textPrimary: DesignRGB
    public let textSecondary: DesignRGB
    public let outline: DesignRGB
    /// The app accent: primary button fill, and the tint for links, toolbar icons and text cursors.
    public let accent: DesignRGB
    /// Label colour on top of `accent` (white in light mode, near-black in dark mode).
    public let onAccent: DesignRGB
    /// A quiet wash of the accent for selected or highlighted backgrounds.
    public let accentTint: DesignRGB
    public let affirm: TonePair
    public let nudge: TonePair
    public let neutral: TonePair
    /// Amber: the streak flame.
    public let flame: StreakTone
    /// Blue: a streak freeze (snowflake).
    public let freeze: StreakTone
    /// Green: the daily goal met.
    public let goalMet: StreakTone
    /// Deep red on a pale red tint, for Reset progress only. Not a feedback tone and never used for answers.
    public let destructive: TonePair

    public static let light = Palette(scheme: .light)
    public static let dark = Palette(scheme: .dark)

    public init(scheme: Scheme) {
        self.scheme = scheme
        switch scheme {
        case .light:
            background = DesignRGB(hex: 0xF0EAFA)
            surface = DesignRGB(hex: 0xFCFAFF)
            textPrimary = DesignRGB(hex: 0x1D1B24)
            textSecondary = DesignRGB(hex: 0x56535F)
            outline = DesignRGB(hex: 0xCBC6D8)
            accent = DesignRGB(hex: 0x5B3FA8)
            onAccent = DesignRGB(hex: 0xFFFFFF)
            accentTint = DesignRGB(hex: 0xE4DBF6)
            affirm = TonePair(background: DesignRGB(hex: 0xCAE8D4), foreground: DesignRGB(hex: 0x14462A))
            nudge = TonePair(background: DesignRGB(hex: 0xF6E0B0), foreground: DesignRGB(hex: 0x5C3A00))
            neutral = TonePair(background: DesignRGB(hex: 0xD3DEEE), foreground: DesignRGB(hex: 0x22344F))
            flame = StreakTone(background: 0xF9DDB0, foreground: 0x6B3300, glyph: 0xB45309)
            freeze = StreakTone(background: 0xCFE3F7, foreground: 0x0F3D66, glyph: 0x1D6FB8)
            goalMet = StreakTone(background: 0xCBEAD7, foreground: 0x0F4A27, glyph: 0x1E7B43)
            destructive = TonePair(background: DesignRGB(hex: 0xFBE4E1), foreground: DesignRGB(hex: 0x8F1D14))
        case .dark:
            background = DesignRGB(hex: 0x1A1821)
            surface = DesignRGB(hex: 0x24212D)
            textPrimary = DesignRGB(hex: 0xF2F1F5)
            textSecondary = DesignRGB(hex: 0xB1AEBC)
            outline = DesignRGB(hex: 0x3F3B4A)
            accent = DesignRGB(hex: 0xB79CF0)
            onAccent = DesignRGB(hex: 0x1A1821)
            accentTint = DesignRGB(hex: 0x33294F)
            affirm = TonePair(background: DesignRGB(hex: 0x173825), foreground: DesignRGB(hex: 0xBDEBC8))
            nudge = TonePair(background: DesignRGB(hex: 0x3B2A0A), foreground: DesignRGB(hex: 0xFFDDA0))
            neutral = TonePair(background: DesignRGB(hex: 0x1F2A3B), foreground: DesignRGB(hex: 0xCCDAF0))
            flame = StreakTone(background: 0x3F2A08, foreground: 0xFFD9A0, glyph: 0xFFA033)
            freeze = StreakTone(background: 0x16304A, foreground: 0xC4E1FF, glyph: 0x6CB6F5)
            goalMet = StreakTone(background: 0x173B26, foreground: 0xBDEBC8, glyph: 0x5CCB84)
            destructive = TonePair(background: DesignRGB(hex: 0x3D1A17), foreground: DesignRGB(hex: 0xFFB4AB))
        }
    }

    public init(_ colorScheme: ColorScheme) {
        self.init(scheme: Scheme(colorScheme))
    }

    public func tone(_ tone: FeedbackTone) -> TonePair {
        switch tone {
        case .affirm: affirm
        case .nudge: nudge
        case .neutral: neutral
        }
    }

    /// Every colour with a stable name, for tests and tooling.
    public var allColors: [(name: String, rgb: DesignRGB)] {
        var colors: [(name: String, rgb: DesignRGB)] = [
            ("background", background), ("surface", surface),
            ("textPrimary", textPrimary), ("textSecondary", textSecondary), ("outline", outline),
            ("accent", accent), ("onAccent", onAccent), ("accentTint", accentTint),
            ("affirm.background", affirm.background), ("affirm.foreground", affirm.foreground),
            ("nudge.background", nudge.background), ("nudge.foreground", nudge.foreground),
            ("neutral.background", neutral.background), ("neutral.foreground", neutral.foreground)
        ]
        for entry in streakTones {
            colors.append(("\(entry.name).background", entry.tone.background))
            colors.append(("\(entry.name).foreground", entry.tone.foreground))
            colors.append(("\(entry.name).glyph", entry.tone.glyph))
        }
        return colors
    }

    /// The three streak tones with stable names, for tests and tooling.
    public var streakTones: [(name: String, tone: StreakTone)] {
        [("flame", flame), ("freeze", freeze), ("goalMet", goalMet)]
    }

    public var backgroundColor: Color { background.color }
    public var surfaceColor: Color { surface.color }
    public var textPrimaryColor: Color { textPrimary.color }
    public var textSecondaryColor: Color { textSecondary.color }
    public var outlineColor: Color { outline.color }
    public var accentColor: Color { accent.color }
    public var onAccentColor: Color { onAccent.color }
    public var accentTintColor: Color { accentTint.color }
}
