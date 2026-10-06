import BLTFeatures
import SwiftUI

@main
struct BLTAppMain: App {
    /// `nil` only for the instant it takes the composition root to finish.
    @State private var dependencies: AppDependencies?

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                RootView(dependencies: dependencies)
            } else {
                ProgressView()
                    .task { dependencies = await CompositionRoot().makeDependencies() }
            }
        }
    }
}
