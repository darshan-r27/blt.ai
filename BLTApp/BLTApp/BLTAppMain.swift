import BLTFeatures
import SwiftUI

@main
struct BLTAppMain: App {
    /// `nil` only for the instant it takes the composition root to finish.
    @State private var composed: CompositionRoot.Composed?
    /// Changing it gives the root view a new identity, so the whole tree is built again and asks the
    /// composition root for the current language's course, which loads that language's catalog afresh. That
    /// returns the learner to Home, which is accepted after an import or a removal.
    @State private var generation = 0
    @State private var notice: String?

    var body: some Scene {
        WindowGroup {
            content
                .uiTestMotionOff()
                // On the container, not on the root view: the root gets a new identity after an import, and an
                // alert attached to a view that is being replaced is never shown.
                .alert("Lessons", isPresented: noticeIsShown) {
                    Button("OK") { notice = nil }
                } message: {
                    Text(notice ?? "")
                }
        }
    }

    @ViewBuilder private var content: some View {
        if let composed {
            RootView(
                profileStore: composed.profileStore,
                makeCourse: composed.makeCourse,
                practice: composed.practice,
                onLessonsChanged: { change in lessonsDidChange(change) }
            )
            .id(generation)
        } else {
            ProgressView()
                .task { composed = await CompositionRoot().compose() }
        }
    }

    private var noticeIsShown: Binding<Bool> {
        Binding(
            get: { notice != nil },
            set: { shown in
                if !shown { notice = nil }
            }
        )
    }

    /// Nothing to rebuild here: `Composed.makeCourse` loads the catalog each time it is asked, so a new root
    /// picks up the lessons just imported or removed, for the language read from the profile. The progress
    /// stores and the profile are the ones already in `composed`, so nothing is erased.
    private func lessonsDidChange(_ change: LessonChange) {
        generation += 1
        switch change {
        case .imported(let count):
            notice = count == 1
                ? "Lessons updated: 1 scenario imported."
                : "Lessons updated: \(count) scenarios imported."
        case .removed:
            notice = "Imported lessons removed. The lessons that came with the app are in use."
        }
    }
}

#if DEBUG
import UIKit
#endif

extension View {
    /// In a UI-test launch only, switches animations off for the whole app, so the shimmer stops and screens change
    /// without animation and UI tests no longer wait for the app to go idle between frames. SwiftUI has no setting
    /// for this (Reduce Motion is read-only), so this uses `UIView.setAnimationsEnabled`, the one UIKit call in the
    /// app, in Debug builds only. Any other launch, and every Release build, is left alone.
    @ViewBuilder fileprivate func uiTestMotionOff() -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(UITestLaunch.fixturesArgument) {
            onAppear { UIView.setAnimationsEnabled(false) }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
