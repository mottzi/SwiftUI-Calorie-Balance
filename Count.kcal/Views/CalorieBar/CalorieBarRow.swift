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
            CalorieBarFill(
                values: values,
                side: side,
                palette: palette,
                rendering: rendering
            )
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
