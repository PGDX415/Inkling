import SwiftUI

/// A layout that arranges subviews in horizontal rows, wrapping to the next line when needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.last?.maxY ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in computeRows(proposal: proposal, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: .unspecified
                )
            }
        }
    }

    private struct Row {
        var items: [(index: Int, x: CGFloat, width: CGFloat)] = []
        var y: CGFloat = 0
        var maxY: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        for (i, sv) in subviews.enumerated() {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].items.isEmpty {
                rows[rows.count - 1].maxY = rows[rows.count - 1].y + size.height
                rows.append(Row())
                x = 0
            }
            rows[rows.count - 1].items.append((index: i, x: x, width: size.width))
            x += size.width + spacing
        }
        var y: CGFloat = 0
        for i in rows.indices {
            rows[i].y = y
            if let mh = rows[i].items.compactMap({ subviews[$0.index].sizeThatFits(.unspecified).height }).max() {
                y += mh + spacing
            }
        }
        return rows
    }
}
