import SwiftUI

/// One answer option. Takes plain text so BLTDesign needs no Session types; the caller maps
/// its own state (asking, chosen, revealed) onto `State`.
public struct OptionButton: View {
    public enum State: Sendable, Equatable {
        /// Awaiting an answer.
        case normal
        /// The option the person chose, coloured by the verdict's tone.
        case selected(FeedbackTone)
        /// The canonical answer, revealed after the person chose something else.
        case correct
        /// Not relevant any more; quieter, but still readable.
        case dimmed
    }

    private let text: String
    private let state: State
    private let action: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var minimumHeight: Double = 44
    @ScaledMetric(relativeTo: .body) private var padding: Double = 12

    public init(_ text: String, state: State = .normal, action: @escaping @MainActor () -> Void) {
        self.text = text
        self.state = state
        self.action = action
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        let colors = resolvedColors(palette)
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: padding) {
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let symbol = symbolName {
                    Image(systemName: symbol)
                        .font(.body)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(colors.foreground)
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: max(44, minimumHeight), alignment: .leading)
            .background(colors.background, in: shape)
            .overlay(shape.strokeBorder(colors.border, lineWidth: colors.borderWidth))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityStateText)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    private struct Colors {
        let background: Color
        let foreground: Color
        let border: Color
        let borderWidth: Double
    }

    private func resolvedColors(_ palette: Palette) -> Colors {
        switch state {
        case .normal:
            return Colors(
                background: palette.surfaceColor,
                foreground: palette.textPrimaryColor,
                border: palette.outlineColor,
                borderWidth: 1
            )
        case .dimmed:
            return Colors(
                background: palette.surfaceColor,
                foreground: palette.textSecondaryColor,
                border: palette.outlineColor,
                borderWidth: 1
            )
        case .selected(let tone):
            return toneColors(palette.tone(tone))
        case .correct:
            return toneColors(palette.affirm)
        }
    }

    private func toneColors(_ pair: Palette.TonePair) -> Colors {
        Colors(
            background: pair.backgroundColor,
            foreground: pair.foregroundColor,
            border: pair.foregroundColor,
            borderWidth: 2
        )
    }

    /// A symbol so state is never carried by colour alone.
    private var symbolName: String? {
        switch state {
        case .normal, .dimmed: nil
        case .correct: "checkmark.circle.fill"
        case .selected(let tone):
            switch tone {
            case .affirm: "checkmark.circle.fill"
            case .nudge: "arrow.left.arrow.right.circle"
            case .neutral: "info.circle"
            }
        }
    }

    private var accessibilityStateText: String {
        switch state {
        case .normal, .dimmed: ""
        case .correct: "Correct answer"
        case .selected(let tone):
            switch tone {
            case .affirm: "Your answer, correct"
            case .nudge: "Your answer, right sentence for a different register"
            case .neutral: "Your answer, not quite"
            }
        }
    }
}

#Preview("Default, light") {
    OptionButtonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Default, dark") {
    OptionButtonPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Largest accessibility size, light") {
    OptionButtonPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Largest accessibility size, dark") {
    OptionButtonPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}

private struct OptionButtonPreviewGallery: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                OptionButton("zz option, default", action: {})
                OptionButton("zz option, chosen and right", state: .selected(.affirm), action: {})
                OptionButton("zz option, chosen, other register", state: .selected(.nudge), action: {})
                OptionButton("zz option, chosen, not quite", state: .selected(.neutral), action: {})
                OptionButton("zz option, revealed correct", state: .correct, action: {})
                OptionButton("zz option, dimmed, with a long line that wraps", state: .dimmed, action: {})
            }
            .padding()
        }
        .background(Palette(colorScheme).backgroundColor)
    }
}
