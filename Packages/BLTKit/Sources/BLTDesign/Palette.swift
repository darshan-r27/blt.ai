import SwiftUI

/// Explicit light/dark palette. There is deliberately no red: feedback colour comes only from
/// `FeedbackTone`, and tones read as affirming (green), gentle (amber) and calm (blue-grey).
/// Contrast (WCAG >= 4.5:1) and the no-red rule are enforced by `PaletteTests`.
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

    public let scheme: Scheme

    public let background: DesignRGB
    public let surface: DesignRGB
    public let textPrimary: DesignRGB
    public let textSecondary: DesignRGB
    public let outline: DesignRGB
    public let affirm: TonePair
    public let nudge: TonePair
    public let neutral: TonePair

    public static let light = Palette(scheme: .light)
    public static let dark = Palette(scheme: .dark)

    public init(scheme: Scheme) {
        self.scheme = scheme
        switch scheme {
        case .light:
            background = DesignRGB(hex: 0xF6F5F1)
            surface = DesignRGB(hex: 0xFFFFFF)
            textPrimary = DesignRGB(hex: 0x1C1D20)
            textSecondary = DesignRGB(hex: 0x55585F)
            outline = DesignRGB(hex: 0xC9CCD1)
            affirm = TonePair(background: DesignRGB(hex: 0xDDF1E2), foreground: DesignRGB(hex: 0x14462A))
            nudge = TonePair(background: DesignRGB(hex: 0xFCEBC8), foreground: DesignRGB(hex: 0x5C3A00))
            neutral = TonePair(background: DesignRGB(hex: 0xE1E8F2), foreground: DesignRGB(hex: 0x22344F))
        case .dark:
            background = DesignRGB(hex: 0x121316)
            surface = DesignRGB(hex: 0x1C1E22)
            textPrimary = DesignRGB(hex: 0xF1F2F4)
            textSecondary = DesignRGB(hex: 0xAEB3BB)
            outline = DesignRGB(hex: 0x3A3E45)
            affirm = TonePair(background: DesignRGB(hex: 0x173825), foreground: DesignRGB(hex: 0xBDEBC8))
            nudge = TonePair(background: DesignRGB(hex: 0x3B2A0A), foreground: DesignRGB(hex: 0xFFDDA0))
            neutral = TonePair(background: DesignRGB(hex: 0x1F2A3B), foreground: DesignRGB(hex: 0xCCDAF0))
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
        [
            ("background", background), ("surface", surface),
            ("textPrimary", textPrimary), ("textSecondary", textSecondary), ("outline", outline),
            ("affirm.background", affirm.background), ("affirm.foreground", affirm.foreground),
            ("nudge.background", nudge.background), ("nudge.foreground", nudge.foreground),
            ("neutral.background", neutral.background), ("neutral.foreground", neutral.foreground)
        ]
    }

    public var backgroundColor: Color { background.color }
    public var surfaceColor: Color { surface.color }
    public var textPrimaryColor: Color { textPrimary.color }
    public var textSecondaryColor: Color { textSecondary.color }
    public var outlineColor: Color { outline.color }
}
