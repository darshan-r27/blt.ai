import SwiftUI

/// Plain numeric sRGB colour (components 0...1) so palette rules can be tested without rendering.
public struct DesignRGB: Sendable, Equatable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `0xRRGGBB`.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private var maxComponent: Double { max(red, green, blue) }
    private var minComponent: Double { min(red, green, blue) }

    /// Hue in degrees, 0 ..< 360. Meaningless (0) for greys.
    public var hue: Double {
        let delta = maxComponent - minComponent
        guard delta > 0 else { return 0 }
        let sector: Double
        if maxComponent == red {
            sector = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxComponent == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// HSV saturation, 0...1.
    public var saturation: Double {
        maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
    }

    /// True when the colour is a red: hue within 345...360 or 0...15 degrees and saturation of 0.2 or more.
    public var isRed: Bool {
        let inRedArc = hue >= 345 || hue <= 15
        return inRedArc && saturation >= 0.2
    }

    /// WCAG 2.x relative luminance.
    public var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.x contrast ratio, 1...21, symmetric in its operands.
    public func contrastRatio(with other: DesignRGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
