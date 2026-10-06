import BLTDesign
import SwiftUI

/// A calm full-screen message for the non-question screens (loading, empty, load error).
struct SessionMessageView: View {
    let title: String
    let message: String
    let actions: [Action]

    struct Action: Identifiable {
        let id: String
        let title: String
        let isPrimary: Bool
        let run: @MainActor () -> Void
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(palette.textSecondaryColor)
                ForEach(actions) { action in
                    if action.isPrimary {
                        Button(action.title, action: action.run)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    } else {
                        Button(action.title, action: action.run)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(palette.backgroundColor)
    }
}
