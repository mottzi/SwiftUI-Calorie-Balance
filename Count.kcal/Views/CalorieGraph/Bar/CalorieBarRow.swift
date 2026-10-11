import SwiftUI

/// One bar with an occupied end cap and values placed across the whole row.
struct CalorieBarRow: View {

    let values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    let configuration: CalorieBarConfiguration
    let palette: CalorieGraphPalette
    var rendering: CalorieGraphRendering = .live

    var body: some View {
        let segments = values.segments(for: side)
        let radius = max(0, configuration.cornerRadius)
        let row = CalorieBarRowLayout(
            values: values,
            side: side,
            labelSpacing: configuration.labelSpacing,
            labelInset: configuration.labelInset
        ) {
            CalorieGraphDrawing(values: values, rendering: rendering) { values in
                CalorieBarFillDrawing(values: values, side: side, palette: palette)
            }
            .clipShape(UnevenRoundedRectangle(
                bottomTrailingRadius: side == .consumed ? radius : 0,
                topTrailingRadius: side == .burned ? radius : 0,
                style: .circular
            ))

            if configuration.showsLabels {
                ForEach(segments, id: \.id.rawValue) { segment in
                    CalorieBarLabel(
                        value: Int(segment.value.rounded()),
                        animatesNumericValues: configuration.animatesNumericValues
                    )
                    .geometryGroup()
                }
            }
        }
        .background(palette.empty.color.opacity(palette.empty.opacity))
        .compositingGroup()
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: side == .burned ? radius : 0,
            bottomLeadingRadius: side == .consumed ? radius : 0,
            bottomTrailingRadius: side == .consumed ? radius : 0,
            topTrailingRadius: side == .burned ? radius : 0,
            style: .continuous
        ))

        if configuration.animatesNumericValues {
            row
        } else {
            row.drawingGroup()
        }
    }

}

extension CalorieBarRow {

    /// Active, resting, or consumed segments within the occupied part of a bar.
    private struct CalorieBarFillDrawing: View {

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
                        let width = occupied > 0
                            ? geometry.size.width * (range.upperBound - range.lowerBound) / occupied
                            : 0
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

}
