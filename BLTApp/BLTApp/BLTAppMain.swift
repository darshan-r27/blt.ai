import BLTFeatures
import SwiftUI

@main
struct BLTAppMain: App {
    /// `nil` only for the instant it takes the composition root to finish.
    @State private var composed: CompositionRoot.Composed?

    var body: some Scene {
        WindowGroup {
            if let composed {
                RootView(dependencies: composed.dependencies, profileStore: composed.profileStore)
            } else {
                ProgressView()
                    .task { composed = await CompositionRoot().compose() }
            }
        }
    }
}
