import SwiftUI

/// Burned and consumed rings with a shared scale and stable projected-resting segment.
struct CalorieCircleGraph: View {

    let energy: EnergyBalance
    var configuration = CalorieCircleConfiguration()
    let palette: CalorieGraphPalette
    var rendering: CalorieGraphRendering = .live

    var body: some View {
        let values = EnergyGraphValues(energy)
        Group {
            CalorieGraphDrawing(values: values, rendering: rendering) { values in
                CalorieCircleDrawing(values: values, configuration: configuration, palette: palette)
            }
        }
        .modifier(CalorieGraphAnimation(values: values, duration: configuration.animationDuration))
        .graphColorAppearance()
        .accessibilityHidden(true)
    }

}

extension CalorieCircleGraph {

    /// Burned and consumed rings with the same scale and fitted stroke spacing.
    private struct CalorieCircleDrawing: View {

        let values: EnergyGraphValues
        let configuration: CalorieCircleConfiguration
        let palette: CalorieGraphPalette

        var body: some View {
            GeometryReader { geometry in
                let diameter = max(0, min(geometry.size.width, geometry.size.height))
                let fitted = configuration.fitted(to: diameter)
                ZStack {
                    CalorieCircleRing(
                        segments: values.burnedSegments,
                        diameter: diameter - fitted.lineWidth,
                        configuration: fitted,
                        palette: palette
                    )
                    CalorieCircleRing(
                        segments: values.consumedSegments,
                        diameter: diameter - 3 * fitted.lineWidth - 2 * fitted.ringSpacing,
                        configuration: fitted,
                        palette: palette
                    )
                }
                .frame(width: diameter, height: diameter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

    }

    /// One segmented ring with transparent space at its internal joins.
    private struct CalorieCircleRing: View {

        let segments: [EnergyGraphValues.Segment]
        let diameter: CGFloat
        let configuration: CalorieCircleConfiguration
        let palette: CalorieGraphPalette

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

    /// One energy arc with a matching track beneath translucent colors.
    private struct CalorieCircleArc: View {

        let range: ClosedRange<Double>
        let fill: CalorieGraphPalette.Fill
        let background: CalorieGraphPalette.Fill
        let hasBackground: Bool
        let cutout: Double
        let lineWidth: CGFloat

        var body: some View {
            ZStack {
                CircleProgressView(
                    progress: range.upperBound,
                    color: background.color,
                    cutout: cutout,
                    lineWidth: lineWidth,
                    startProgress: range.lowerBound
                )
                .brightness(background.brightness)
                .opacity(hasBackground ? background.opacity : 0)

                CircleProgressView(
                    progress: range.upperBound,
                    color: fill.color,
                    cutout: cutout,
                    lineWidth: lineWidth,
                    startProgress: range.lowerBound
                )
                .brightness(fill.brightness)
                .opacity(fill.opacity)
            }
        }

    }

}
