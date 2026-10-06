import SwiftUI

/// Word-by-word gloss: small Tamil/English pairs in a wrapping layout. Takes plain strings so
/// BLTDesign does not depend on the catalog.
public struct GlossView: View {
    private let pairs: [(tamil: String, english: String)]

    @Environment(\.colorScheme) private var colorScheme

    public init(_ pairs: [(tamil: String, english: String)]) {
        self.pairs = pairs
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        DesignWrappingLayout(horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.tamil)
                        .font(.body)
                        .foregroundStyle(palette.textPrimaryColor)
                    Text(pair.english)
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondaryColor)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.outlineColor, lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(pair.tamil), meaning \(pair.english)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Word by word meanings")
    }
}

private let previewPairs: [(tamil: String, english: String)] = [
    (tamil: "zz-one", english: "first word"),
    (tamil: "zz-two", english: "second"),
    (tamil: "zz-three-longer", english: "a longer meaning that wraps onto more than one line"),
    (tamil: "zz-four", english: "fourth"),
    (tamil: "zz-five", english: "fifth word")
]

#Preview("Default, light") {
    GlossView(previewPairs)
        .padding()
        .background(Palette.light.backgroundColor)
        .preferredColorScheme(.light)
}

#Preview("Default, dark") {
    GlossView(previewPairs)
        .padding()
        .background(Palette.dark.backgroundColor)
        .preferredColorScheme(.dark)
}

#Preview("Largest accessibility size, light") {
    ScrollView {
        GlossView(previewPairs)
            .padding()
    }
    .background(Palette.light.backgroundColor)
    .environment(\.dynamicTypeSize, .accessibility5)
    .preferredColorScheme(.light)
}

#Preview("Largest accessibility size, dark") {
    ScrollView {
        GlossView(previewPairs)
            .padding()
    }
    .background(Palette.dark.backgroundColor)
    .environment(\.dynamicTypeSize, .accessibility5)
    .preferredColorScheme(.dark)
}
