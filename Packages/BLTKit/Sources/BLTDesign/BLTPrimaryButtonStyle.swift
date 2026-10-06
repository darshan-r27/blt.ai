import SwiftUI

/// The style for a screen's one main action: a filled accent button with the accent's own label colour.
///
/// Text styles only, so it follows Dynamic Type; the label wraps rather than truncating; the height
/// grows with the text and never drops below 44 pt. It is deliberately not tied to the button's
/// `role`, so a destructive-role button never turns system red (the app has no red).
public struct BLTPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        BLTPrimaryButtonBody(configuration: configuration)
    }
}

public extension ButtonStyle where Self == BLTPrimaryButtonStyle {
    /// `Button("Continue") { … }.buttonStyle(.bltPrimary)`
    static var bltPrimary: BLTPrimaryButtonStyle { BLTPrimaryButtonStyle() }
}

private struct BLTPrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var minimumHeight: Double = 44
    @ScaledMetric(relativeTo: .body) private var padding: Double = 12

    var body: some View {
        let palette = Palette(colorScheme)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.onAccentColor)
            .padding(.horizontal, padding * 1.5)
            .padding(.vertical, padding)
            .frame(maxWidth: .infinity, minHeight: max(44, minimumHeight))
            .background(palette.accentColor, in: shape)
            // Pressed is a quiet dim (no motion, so Reduce Motion needs no special case); disabled is dimmer still.
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(shape)
    }
}

#Preview("Primary button, light") {
    BLTPrimaryButtonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Primary button, dark") {
    BLTPrimaryButtonPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Primary button, largest accessibility size") {
    BLTPrimaryButtonPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.light)
}

private struct BLTPrimaryButtonPreviewGallery: View {
    var body: some View {
        VStack(spacing: 12) {
            Button("zz Get started", action: {})
                .buttonStyle(.bltPrimary)
            Button("zz A longer label that has to wrap onto a second line", action: {})
                .buttonStyle(.bltPrimary)
            Button("zz Disabled", action: {})
                .buttonStyle(.bltPrimary)
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .bltTheme()
        .bltScreenBackground()
    }
}
