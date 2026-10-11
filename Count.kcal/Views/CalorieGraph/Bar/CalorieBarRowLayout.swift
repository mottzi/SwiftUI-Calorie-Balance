import SwiftUI

/// Bar fill placement and label spacing with room reserved for neighboring values.
struct CalorieBarRowLayout: Layout {

    typealias Cache = Void

    var values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    var labelSpacing: CGFloat = 4
    var labelInset: CGFloat = 4

    /// Places the fill and keeps complete target labels apart as segment widths change.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {

        guard let fill = subviews.first else { return }
        let width = finiteDimension(bounds.width)
        let height = finiteDimension(bounds.height)
        let segments = values.segments(for: side)
        let occupiedEnd = segments.last(where: { $0.id != .empty })?.range.upperBound ?? 0
        let occupiedWidth = width * CGFloat(min(max(occupiedEnd, 0), 1))

        fill.place(
            at: CGPoint(x: bounds.minX + occupiedWidth / 2, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: occupiedWidth, height: height)
        )

        let labels = Array(subviews.dropFirst())
        let sizes = labels.map { subview in
            let measured = subview.sizeThatFits(.unspecified)
            return CGSize(width: finiteDimension(measured.width), height: finiteDimension(measured.height))
        }
        let presence = labels.map { $0[CalorieBarLabel.PresenceKey.self] }
        let placements = labelPlacements(
            segments: segments,
            sizes: sizes,
            presence: presence,
            width: width,
            height: height
        )
        for index in labels.indices {
            let placement = placements[index]
            labels[index].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(
                    width: placement.center + sizes[index].width / 2,
                    height: placement.visible ? sizes[index].height : 0
                )
            )
        }
    }

    /// Interpolates label positions with the same values and scale as the bar fill.
    var animatableData: EnergyGraphValues.AnimatableData {
        get { values.animatableData }
        set { values.animatableData = newValue }
    }

    /// Uses the proposed row dimensions, with zero for missing or invalid dimensions.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        CGSize(width: finiteDimension(proposal.width), height: finiteDimension(proposal.height))
    }

}

extension CalorieBarRowLayout {

    private func labelPlacements(
        segments: [EnergyGraphValues.Segment],
        sizes: [CGSize],
        presence: [Bool],
        width: CGFloat,
        height: CGFloat
    ) -> [Placement] {

        var placements = Array(repeating: Placement(), count: sizes.count)
        var slots = Array<LabelSlot?>(repeating: nil, count: sizes.count)
        var earliestTrailingEdge: CGFloat?
        let spacing = finiteDimension(labelSpacing)
        let inset = finiteDimension(labelInset)

        // Reserve enough space for leading labels before choosing any preferred centers.
        for index in sizes.indices {
            guard segments.indices.contains(index) else { continue }
            let segment = segments[index]
            let start = width * CGFloat(segment.range.lowerBound)
            let end = width * CGFloat(segment.range.upperBound)
            let glyphWidth = sizes[index].width
            let halfWidth = glyphWidth / 2
            let centered = (start + end) / 2
            placements[index].center = centered
            guard presence[index], width > 0, height > 0, segment.value > 0, end > start, glyphWidth > 0 else { continue }
            guard sizes[index].height <= height else { continue }

            let minimumCenter: CGFloat
            let desiredCenter: CGFloat
            let maximumCenter: CGFloat

            if segment.id == .prediction || segment.id == .empty {
                minimumCenter = inset + halfWidth
                maximumCenter = min(end - inset - halfWidth, width - inset - halfWidth)
                desiredCenter = glyphWidth + 2 * inset <= end - start ? centered : maximumCenter
            } else {
                // Primary values can borrow trailing space while keeping their leading segment boundary.
                minimumCenter = start == 0 ? inset + halfWidth : start + halfWidth
                maximumCenter = width - inset - halfWidth
                desiredCenter = centered
            }
            guard minimumCenter <= maximumCenter else { continue }

            let leadingLimit = earliestTrailingEdge.map { $0 + spacing + halfWidth } ?? minimumCenter
            let earliestCenter = max(minimumCenter, leadingLimit)
            slots[index] = LabelSlot(
                halfWidth: halfWidth,
                minimumCenter: minimumCenter,
                earliestCenter: earliestCenter,
                desiredCenter: desiredCenter,
                maximumCenter: maximumCenter
            )
            earliestTrailingEdge = earliestCenter + halfWidth
        }

        var nextLeadingEdge: CGFloat?
        for index in slots.indices.reversed() {
            guard let slot = slots[index] else { continue }
            let trailingLimit = nextLeadingEdge.map { $0 - spacing - slot.halfWidth } ?? slot.maximumCenter
            let maximumCenter = min(slot.maximumCenter, trailingLimit)
            // Preserve trailing priority only when the entire leading group cannot fit.
            let minimumCenter = slot.earliestCenter <= maximumCenter ? slot.earliestCenter : slot.minimumCenter
            guard minimumCenter <= maximumCenter else { continue }
            let center = min(max(slot.desiredCenter, minimumCenter), maximumCenter)
            placements[index] = Placement(center: center, visible: true)
            nextLeadingEdge = center - slot.halfWidth
        }
        return placements
    }

    private func finiteDimension(_ dimension: CGFloat?) -> CGFloat {
        guard let dimension, dimension.isFinite else { return 0 }
        return max(0, dimension)
    }

    /// Allowed label centers and the space reserved by preceding labels.
    private struct LabelSlot {
        let halfWidth: CGFloat
        let minimumCenter: CGFloat
        let earliestCenter: CGFloat
        let desiredCenter: CGFloat
        let maximumCenter: CGFloat
    }

    /// Final label center and visibility for one layout pass.
    private struct Placement {
        var center: CGFloat = 0
        var visible = false
    }

}
