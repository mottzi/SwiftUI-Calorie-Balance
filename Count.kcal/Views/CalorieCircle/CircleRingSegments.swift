import SwiftUI

/// Ordered ring ranges with gaps that narrow around small energy segments.
struct CircleRingSegments {

    let ranges: [ClosedRange<Double>]

    init(boundaries: [Double], radius: CGFloat, cutout: Double = 0.25, gapWidth: CGFloat = 2) {
        let arcLength = max(0, radius) * 2 * .pi * (1 - min(max(cutout, 0), 1))
        let halfGap = arcLength > 0 ? max(0, gapWidth) / (2 * arcLength) : 0
        ranges = zip(boundaries.indices.dropLast(), boundaries.indices.dropFirst()).map { lower, upper in
            let start = boundaries[lower]
            let end = boundaries[upper]
            let segmentLimit = (end - start) / 4
            let leading = min(halfGap, segmentLimit, start / 4)
            let trailing = min(halfGap, segmentLimit, (1 - end) / 4)
            return (start + leading)...(end - trailing)
        }
    }

}
