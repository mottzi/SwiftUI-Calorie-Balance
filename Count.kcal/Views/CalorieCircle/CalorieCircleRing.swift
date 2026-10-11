import SwiftUI

/// One segmented ring with transparent space at its internal joins.
struct CalorieCircleRing: View {

    let segments: [EnergyGraphValues.Segment]
    let diameter: CGFloat
    let configuration: CalorieCircleConfiguration
    let palette: CalorieCirclePalette

    var body: some View {
        let cutout = configuration.openAngle.degrees / 360
        let ring = CircleRingSegments(
            boundaries: [0] + segments.map { $0.range.upperBound },
            radius: diameter / 2,
            cutout: cutout,
            gapWidth: configuration.segmentGap
        )
        ZStack {
            // String IDs preserve arc matching between WidgetKit's archived snapshots.
            ForEach(Array(zip(segments, ring.ranges)), id: \.0.id.rawValue) { segment, range in
                CalorieCircleArc(
                    range: range,
                    fill: palette.fill(for: segment.id),
                    background: palette.empty,
                    hasBackground: segment.id != .empty,
                    cutout: cutout,
                    lineWidth: configuration.lineWidth
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }

}
