import BLTDesign
import SwiftUI

/// The top bar of a session: an X with the visible words "End session", at the leading edge.
///
/// Drawn by `SessionView` itself rather than as a toolbar item, because the session is presented
/// in a full-screen cover with no navigation bar, and the cover cannot be swiped away. The words
/// are visible so the control is legible without knowing what an X means; the 44 pt minimum
/// height meets the touch-target guideline at every text size. It is deliberately quiet
/// (primary text colour, no fill) so it never competes with the answer options.
struct SessionEndControl: View {
    let onTap: @MainActor () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme)
        HStack {
            Button(action: onTap) {
                Label {
                    Text("End session")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.textPrimaryColor)
            .accessibilityIdentifier(AccessibilityID.endSessionButton)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.backgroundColor)
    }
}

#if DEBUG
#Preview("End control, light") {
    SessionEndControl(onTap: {})
        .preferredColorScheme(.light)
}

#Preview("End control, largest accessibility size, dark") {
    SessionEndControl(onTap: {})
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}
#endif
