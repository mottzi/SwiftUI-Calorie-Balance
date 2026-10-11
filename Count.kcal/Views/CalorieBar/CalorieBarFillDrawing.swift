import SwiftUI

/// Native frames and offsets for the occupied portion of one bar.
struct CalorieBarFillDrawing: View {

    @Environment(\.layoutDirection) private var layoutDirection

    let values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    let palette: CalorieGraphPalette

    var body: some View {
        GeometryReader { geometry in
            let segments = values.segments(for: side).dropLast()
            let occupied = segments.last?.range.upperBound ?? 0
            ZStack(alignment: .leading) {
                ForEach(segments, id: \.id.rawValue) { segment in
                    let range = segment.range
                    let width = occupied > 0 ? geometry.size.width * (range.upperBound - range.lowerBound) / occupied : 0
                    let start = occupied > 0 ? geometry.size.width * range.lowerBound / occupied : 0
                    let fill = palette.fill(for: segment.id)
                    Rectangle()
                        .fill(fill.color.gradient)
                        .brightness(fill.brightness)
                        .opacity(fill.opacity)
                        .graphColorAppearance()
                        .frame(width: max(0, width), height: max(0, geometry.size.height))
                        .offset(x: layoutDirection == .rightToLeft ? -start : start)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
    }

}
