import BLTDesign
import SwiftUI
import Testing

struct ScreenBackgroundTests {
    /// Rendering cannot be asserted here; this only pins that the modifier is public and composes.
    @MainActor
    @Test func modifierComposesOnAnyView() {
        let view = Text("zz").bltScreenBackground()
        #expect(String(describing: type(of: view)).contains("ModifiedContent"))
    }
}
