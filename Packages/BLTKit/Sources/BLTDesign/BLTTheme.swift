import SwiftUI

/// Sets the app-wide tint to the palette accent for the current colour scheme, so links, toolbar
/// icons, bordered buttons, text-field cursors and selection handles all pick up the purple.
private struct BLTThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.tint(Palette(colorScheme).accentColor)
    }
}

public extension View {
    /// Apply once at the root of the app. Sheets and full-screen covers inherit the tint from the
    /// view that presents them.
    func bltTheme() -> some View {
        modifier(BLTThemeModifier())
    }
}
