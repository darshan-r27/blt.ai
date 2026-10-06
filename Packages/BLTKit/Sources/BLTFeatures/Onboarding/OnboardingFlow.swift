import SwiftUI

/// Intro, then Name entry. Saving the name hands control back to the gate, which then shows Home.
struct OnboardingFlow: View {
    let gate: ProfileGateViewModel
    @State private var nameEntry: NameEntryViewModel

    init(gate: ProfileGateViewModel) {
        self.gate = gate
        _nameEntry = State(initialValue: gate.makeNameEntryViewModel())
    }

    var body: some View {
        switch gate.onboardingStep {
        case .intro:
            IntroView(onStart: gate.showNameEntry)
        case .nameEntry:
            NameEntryView(viewModel: nameEntry)
        }
    }
}
