import SwiftUI

/// Left-to-right flow layout that wraps to a new row when the next subview does not fit.
/// Subviews are placed in order, so reading order equals declaration order.
struct DesignWrappingLayout: Layout {
    var horizontalSpacing: Double
    var verticalSpacing: Double

    init(horizontalSpacing: Double = 12, verticalSpacing: Double = 10) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let placements = arrange(subviews: subviews, maxWidth: maxWidth)
        return placements.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = arrange(subviews: subviews, maxWidth: bounds.width)
        for (index, frame) in placements.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private struct Arrangement {
        var frames: [CGRect]
        var size: CGSize
    }

    private func arrange(subviews: Subviews, maxWidth: Double) -> Arrangement {
        var frames: [CGRect] = []
        var cursorX = 0.0
        var cursorY = 0.0
        var rowHeight = 0.0
        var usedWidth = 0.0

        for subview in subviews {
            // Each item may be at most one row wide, so long text wraps inside its own cell.
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if cursorX > 0, cursorX + size.width > maxWidth {
                cursorX = 0
                cursorY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            frames.append(CGRect(x: cursorX, y: cursorY, width: size.width, height: size.height))
            cursorX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, cursorX - horizontalSpacing)
        }
        return Arrangement(frames: frames, size: CGSize(width: usedWidth, height: cursorY + rowHeight))
    }
}
