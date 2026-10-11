import SwiftUI

/// Burned and consumed bars with the circle graph's scale and stable segment slots.
struct CalorieBarGraph: View {

    let energy: EnergyBalance
    var configuration = CalorieBarConfiguration()
    let palette: CalorieGraphPalette
    var rendering: CalorieGraphRendering = .live

    var body: some View {
        let values = EnergyGraphValues(energy)
        GeometryReader { geometry in
            let spacing = min(max(configuration.rowSpacing, 0), max(0, geometry.size.height))
            let rowHeight = max(0, (geometry.size.height - spacing) / 2)
            VStack(spacing: spacing) {
                CalorieBarRow(
                    values: values,
                    side: .burned,
                    configuration: configuration,
                    palette: palette,
                    rendering: rendering
                )
                .frame(height: rowHeight)
                CalorieBarRow(
                    values: values,
                    side: .consumed,
                    configuration: configuration,
                    palette: palette,
                    rendering: rendering
                )
                .frame(height: rowHeight)
            }
        }
        .modifier(CalorieGraphAnimation(values: values, duration: configuration.animationDuration))
    }

}
