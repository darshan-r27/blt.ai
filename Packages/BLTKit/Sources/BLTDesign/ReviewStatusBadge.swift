import SwiftUI

/// Small badge shown wherever an unreviewed item's Tamil appears (DECISIONS 025).
public struct ReviewStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let pair = Palette(colorScheme).tone(.neutral)
        Label {
            Text("Unreviewed draft")
                .font(.footnote)
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: "doc.text")
                .font(.footnote)
        }
        .foregroundStyle(pair.foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(pair.backgroundColor, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unreviewed draft")
        .accessibilityHint("This content was drafted by an AI and has not yet been checked by a native speaker.")
        .accessibilityIdentifier(AccessibilityID.badgeUnreviewed)
    }
}

#Preview("Default, light") {
    ReviewStatusBadge()
        .padding()
        .background(Palette.light.backgroundColor)
        .preferredColorScheme(.light)
}

#Preview("Default, dark") {
    ReviewStatusBadge()
        .padding()
        .background(Palette.dark.backgroundColor)
        .preferredColorScheme(.dark)
}

#Preview("Largest accessibility size, light") {
    ReviewStatusBadge()
        .padding()
        .background(Palette.light.backgroundColor)
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Largest accessibility size, dark") {
    ReviewStatusBadge()
        .padding()
        .background(Palette.dark.backgroundColor)
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}
