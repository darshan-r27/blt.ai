import SwiftUI

/// The style for Reset progress wherever it appears: deep red on a pale red tint, an outline in the same red
/// and a bold label, so it reads as a warning (DECISIONS 037). The warning is never colour alone: callers add
/// the triangle symbol to the label. Contrast of the pair is tested in `PaletteTests`.
///
/// Text styles only, so it follows Dynamic Type; the label wraps rather than truncating; the height grows
/// with the text and never drops below 44 pt.
public struct BLTWarningButtonStyle: ButtonStyle {
    private let fillsWidth: Bool

    public init(fillsWidth: Bool = false) {
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        BLTWarningButtonBody(configuration: configuration, fillsWidth: fillsWidth)
    }
}

public extension ButtonStyle where Self == BLTWarningButtonStyle {
    /// `Button { … } label: { Label("Reset progress", systemImage: "exclamationmark.triangle") }.buttonStyle(.bltWarning)`
    static var bltWarning: BLTWarningButtonStyle { BLTWarningButtonStyle() }

    /// The same, stretched to the full width of its container.
    static func bltWarning(fillsWidth: Bool) -> BLTWarningButtonStyle { BLTWarningButtonStyle(fillsWidth: fillsWidth) }
}

private struct BLTWarningButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fillsWidth: Bool

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
            .foregroundStyle(palette.destructive.foregroundColor)
            .padding(.horizontal, padding * 1.5)
            .padding(.vertical, padding)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: max(44, minimumHeight))
            .background(palette.destructive.backgroundColor, in: shape)
            .overlay(shape.strokeBorder(palette.destructive.foregroundColor, lineWidth: 1.5))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(shape)
    }
}

#Preview("Warning button, light") {
    BLTWarningButtonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Warning button, dark") {
    BLTWarningButtonPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Warning button, largest accessibility size") {
    BLTWarningButtonPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.light)
}

private struct BLTWarningButtonPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {}, label: { Label("zz Reset progress", systemImage: "exclamationmark.triangle") })
                .buttonStyle(.bltWarning)
            Button(action: {}, label: { Label("zz Reset, full width", systemImage: "exclamationmark.triangle") })
                .buttonStyle(.bltWarning(fillsWidth: true))
            Button(action: {}, label: { Label("zz Disabled", systemImage: "exclamationmark.triangle") })
                .buttonStyle(.bltWarning)
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .bltTheme()
        .bltScreenBackground()
    }
}
