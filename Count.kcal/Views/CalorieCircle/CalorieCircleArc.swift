import SwiftUI

/// One energy arc with a matching track beneath translucent colors.
struct CalorieCircleArc: View {

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
