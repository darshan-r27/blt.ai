import BLTDesign
import SwiftUI

/// One topic's cheat sheet, shown full screen: the topic's title, then each word in teaching order. Close leaves.
///
/// The rows sit in a plain stack, not a lazy one: a lazy stack does not build rows that scroll out of view
/// when the text grows, and the accessibility audit then cannot compare them.
struct CheatSheetView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let viewModel: CheatSheetViewModel
    private let onClose: @MainActor () -> Void

    init(viewModel: CheatSheetViewModel, onClose: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer(minLength: 0)
                    Button(CheatSheetCopy.closeButton, action: onClose)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier(AccessibilityID.cheatSheetClose)
                }
                Text(viewModel.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                if viewModel.isEmpty {
                    Text(CheatSheetCopy.emptySheet)
                        .font(.body)
                        .foregroundStyle(palette.textSecondaryColor)
                } else {
                    ForEach(viewModel.rows) { row in
                        CheatSheetRowView(row: row)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.cheatSheetScreen)
        }
        .background(palette.backgroundColor)
    }
}
