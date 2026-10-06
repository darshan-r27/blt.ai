import SwiftUI

/// Fills the whole screen, safe areas included, with the palette's page background for the
/// current colour scheme.
private struct ScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            Palette(colorScheme).backgroundColor
                .ignoresSafeArea()
        }
    }
}

public extension View {
    /// Apply to a screen's root view so the lilac page background reaches every edge of the display.
    func bltScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}

#Preview("Card on lilac, light") {
    ScreenBackgroundPreviewSample()
        .preferredColorScheme(.light)
}

#Preview("Card on lilac, dark") {
    ScreenBackgroundPreviewSample()
        .preferredColorScheme(.dark)
}

private struct ScreenBackgroundPreviewSample: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("zz sample card")
                    .font(.headline)
                    .foregroundStyle(palette.textPrimaryColor)
                Text("zz secondary line on a card")
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondaryColor)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.outlineColor, lineWidth: 1)
            )
            OptionButton("zz option, default", action: {})
            OptionButton("zz option, chosen and right", state: .selected(.affirm), action: {})
            OptionButton("zz option, chosen, other register", state: .selected(.nudge), action: {})
            OptionButton("zz option, chosen, not quite", state: .selected(.neutral), action: {})
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .bltScreenBackground()
    }
}
