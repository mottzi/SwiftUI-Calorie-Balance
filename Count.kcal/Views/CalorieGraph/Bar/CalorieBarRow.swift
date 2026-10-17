import SwiftUI
import WidgetKit

/// One bar with an occupied end cap and values placed across the whole row.
struct CalorieBarRow: View {

    @Environment(\.widgetRenderingMode) private var renderingMode

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
                CalorieBarFillDrawing(
                    values: values,
                    side: side,
                    palette: palette,
                    usesCumulativeLayers: rendering == .widget && renderingMode != .accented
                )
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

        if renderingMode == .accented && configuration.showsLabels {
            row.mask(labelMask)
        } else if configuration.animatesNumericValues {
            row
        } else {
            row.drawingGroup()
        }
    }

}

extension CalorieBarRow {

    private var labelMask: some View {
        CalorieBarRowLayout(
            values: values,
            side: side,
            labelSpacing: configuration.labelSpacing,
            labelInset: configuration.labelInset
        ) {
            Color.clear
            ForEach(values.segments(for: side), id: \.id.rawValue) { segment in
                CalorieBarLabel(
                    value: Int(segment.value.rounded()),
                    animatesNumericValues: configuration.animatesNumericValues
                )
                .colorMultiply(.black)
                .opacity(segment.id == .empty ? 0 : 1)
                .geometryGroup()
            }
        }
        .background(.white)
        .compositingGroup()
        .luminanceToAlpha()
    }

    /// Active, resting, or consumed segments within the occupied part of a bar.
    private struct CalorieBarFillDrawing: View {

        @Environment(\.layoutDirection) private var layoutDirection

        let values: EnergyGraphValues
        let side: EnergyGraphValues.Side
        let palette: CalorieGraphPalette
        let usesCumulativeLayers: Bool

        var body: some View {
            GeometryReader { geometry in
                let segments = values.segments(for: side).dropLast()
                let occupied = segments.last?.range.upperBound ?? 0
                let layers = usesCumulativeLayers ? Array(segments.reversed()) : Array(segments)
                ZStack(alignment: .leading) {
                    // Paint cumulative layers from the last segment backwards. A zero-length
                    // projection stays underneath the recorded segments, so WidgetKit can
                    // reveal it by resizing their edges instead of fading a new rectangle in.
                    ForEach(layers, id: \.id.rawValue) { segment in
                        let range = segment.range
                        let start = usesCumulativeLayers ? 0 : range.lowerBound
                        let width = occupied > 0
                            ? geometry.size.width * (range.upperBound - start) / occupied
                            : 0
                        let offset = occupied > 0 ? geometry.size.width * start / occupied : 0
                        let fill = palette.fill(for: segment.id)
                        Rectangle()
                            .fill(fill.color.gradient)
                            .brightness(fill.brightness)
                            .opacity(fill.opacity)
                            .graphColorAppearance()
                            .frame(width: max(0, width), height: max(0, geometry.size.height))
                            .offset(x: layoutDirection == .rightToLeft ? -offset : offset)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            }
        }

    }

}
