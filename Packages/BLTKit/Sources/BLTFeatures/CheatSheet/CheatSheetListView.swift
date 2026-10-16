import BLTDesign
import SwiftUI

/// Every topic of the course being learned, in catalog order. A finished topic opens its sheet; a topic still
/// in progress shows a calm line and cannot be tapped. Close leaves.
struct CheatSheetListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var openSheet: CheatSheetViewModel?

    private let viewModel: CheatSheetListViewModel
    private let onClose: @MainActor () -> Void

    init(viewModel: CheatSheetListViewModel, onClose: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        let palette = Palette(colorScheme)
        ScrollView {
            // Not lazy, for the same reason as the sheet: every row must exist for the accessibility audit.
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer(minLength: 0)
                    Button(CheatSheetCopy.closeButton, action: onClose)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier(AccessibilityID.cheatSheetListClose)
                }
                Text(CheatSheetLabels.screenTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.textPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                if viewModel.isEmpty {
                    Text(CheatSheetCopy.emptyList)
                        .font(.body)
                        .foregroundStyle(palette.textSecondaryColor)
                } else {
                    ForEach(viewModel.rows) { row in
                        rowView(row, palette: palette)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.cheatSheetList)
        }
        .background(palette.backgroundColor)
        .fullScreenCover(item: $openSheet) { sheet in
            CheatSheetView(viewModel: sheet, onClose: { openSheet = nil })
        }
    }

    @ViewBuilder
    private func rowView(_ row: CheatSheetListViewModel.Row, palette: Palette) -> some View {
        if row.isUnlocked {
            Button { openSheet = viewModel.sheetModel(for: row.id) } label: {
                card(row, palette: palette, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityIdentifier(AccessibilityID.cheatSheetListRow(row.id.rawValue))
        } else {
            card(row, palette: palette, showsChevron: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
                .accessibilityIdentifier(AccessibilityID.cheatSheetListRowLocked(row.id.rawValue))
        }
    }

    private func card(_ row: CheatSheetListViewModel.Row, palette: Palette, showsChevron: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(row.isUnlocked ? palette.textPrimaryColor : palette.textSecondaryColor)
                if !row.isUnlocked {
                    Text(CheatSheetLabels.lockedLine)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textSecondaryColor)
                    .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.outlineColor, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
