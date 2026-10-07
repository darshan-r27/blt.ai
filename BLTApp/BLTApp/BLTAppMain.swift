import BLTFeatures
import SwiftUI

@main
struct BLTAppMain: App {
    /// `nil` only for the instant it takes the composition root to finish.
    @State private var composed: CompositionRoot.Composed?
    /// Changing it gives the root view a new identity, so the whole tree is built again on the new catalog.
    /// That returns the learner to Home, which is accepted after an import or a removal.
    @State private var generation = 0
    @State private var notice: String?

    var body: some Scene {
        WindowGroup {
            content
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
                dependencies: composed.dependencies,
                profileStore: composed.profileStore,
                lessonImporter: composed.lessonImporter,
                onLessonsChanged: { change in lessonsDidChange(change, from: composed) }
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

    private func lessonsDidChange(_ change: LessonChange, from current: CompositionRoot.Composed) {
        composed = CompositionRoot().reloaded(current)
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
