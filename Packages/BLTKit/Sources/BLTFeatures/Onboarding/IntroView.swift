import BLTDesign
import SwiftUI

/// First launch only: the app's name in words, one line about it, and one button.
struct IntroView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onStart: () -> Void

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "character.bubble")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(palette.textSecondaryColor)
                    .accessibilityHidden(true)
                Text("blt.ai")
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.textPrimaryColor)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Learn the Tamil people actually speak.")
                    .font(.title3)
                    .foregroundStyle(palette.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onStart) {
                Text("Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bltPrimary)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.introStart)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .bltScreenBackground()
    }
}

#if DEBUG
#Preview("Intro, light") {
    IntroView(onStart: {})
        .preferredColorScheme(.light)
}

#Preview("Intro, dark") {
    IntroView(onStart: {})
        .preferredColorScheme(.dark)
}

#Preview("Intro, largest accessibility size") {
    IntroView(onStart: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
