import SwiftUI

/// Places the occupied fill and resolves all label collisions in the same layout pass.
struct CalorieBarRowLayout: Layout {

    typealias Cache = Void

    var values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    var layoutDirection: LayoutDirection = .leftToRight
    var labelSpacing: CGFloat = 4
    var labelInset: CGFloat = 4

    var animatableData: EnergyGraphValues.AnimatableData {
        get { values.animatableData }
        set { values.animatableData = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        CGSize(width: finiteDimension(proposal.width), height: finiteDimension(proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {

        guard let fill = subviews.first else { return }
        let width = finiteDimension(bounds.width)
        let height = finiteDimension(bounds.height)
        let segments = values.segments(for: side)
        let occupiedEnd = segments.last(where: { $0.id != .empty })?.range.upperBound ?? 0
        let occupiedWidth = width * CGFloat(min(max(occupiedEnd, 0), 1))

        fill.place(
            at: CGPoint(x: physicalX(occupiedWidth / 2, in: bounds), y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: occupiedWidth, height: height)
        )

        let labels = Array(subviews.dropFirst())
        let sizes = labels.map { subview in
            let measured = subview.sizeThatFits(.unspecified)
            return CGSize(width: finiteDimension(measured.width), height: finiteDimension(measured.height))
        }
        let placements = labelPlacements(segments: segments, sizes: sizes, width: width, height: height)
        for index in labels.indices {
            let placement = placements[index]
            labels[index].place(
                at: CGPoint(x: physicalX(0, in: bounds), y: bounds.midY),
                anchor: layoutDirection == .rightToLeft ? .trailing : .leading,
                proposal: ProposedViewSize(
                    width: placement.center + sizes[index].width / 2,
                    height: placement.visible ? sizes[index].height : 0
                )
            )
        }
    }

}

extension CalorieBarRowLayout {

    private func labelPlacements(
        segments: [EnergyGraphValues.Segment],
        sizes: [CGSize],
        width: CGFloat,
        height: CGFloat
    ) -> [Placement] {

        var placements = Array(repeating: Placement(), count: sizes.count)
        var nextLeadingEdge: CGFloat?
        let spacing = finiteDimension(labelSpacing)
        let inset = finiteDimension(labelInset)

        for index in sizes.indices.reversed() {
            guard segments.indices.contains(index) else { continue }
            let segment = segments[index]
            let start = width * CGFloat(segment.range.lowerBound)
            let end = width * CGFloat(segment.range.upperBound)
            let glyphWidth = sizes[index].width
            let halfWidth = glyphWidth / 2
            let centered = (start + end) / 2
            placements[index].center = centered
            guard width > 0, height > 0, segment.value > 0, end > start, glyphWidth > 0 else { continue }
            guard sizes[index].height <= height else { continue }

            let permitsOverflow = segment.id == .prediction || segment.id == .empty
            let minimumCenter: CGFloat
            let desiredCenter: CGFloat
            let maximumCenter: CGFloat

            if start == 0 {
                minimumCenter = inset + halfWidth
                maximumCenter = width - inset - halfWidth
                desiredCenter = centered
            } else if permitsOverflow {
                minimumCenter = inset + halfWidth
                maximumCenter = min(end - inset - halfWidth, width - inset - halfWidth)
                desiredCenter = glyphWidth + 2 * inset <= end - start ? centered : maximumCenter
            } else {
                minimumCenter = start + halfWidth
                maximumCenter = end - halfWidth
                desiredCenter = centered
            }

            let collisionLimit = nextLeadingEdge.map { $0 - spacing - halfWidth } ?? width - halfWidth
            let availableMaximum = min(maximumCenter, collisionLimit)
            guard minimumCenter <= availableMaximum else { continue }
            let center = min(max(desiredCenter, minimumCenter), availableMaximum)
            placements[index] = Placement(center: center, visible: true)
            nextLeadingEdge = center - halfWidth
        }
        return placements
    }

    private func physicalX(_ leadingDistance: CGFloat, in bounds: CGRect) -> CGFloat {
        layoutDirection == .rightToLeft ? bounds.maxX - leadingDistance : bounds.minX + leadingDistance
    }

    private func finiteDimension(_ dimension: CGFloat?) -> CGFloat {
        guard let dimension, dimension.isFinite else { return 0 }
        return max(0, dimension)
    }

    private struct Placement {
        var center: CGFloat = 0
        var visible = false
    }

}
