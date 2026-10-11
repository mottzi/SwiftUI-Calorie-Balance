import SwiftUI

/// Stable bar segments for live drawing and native widget animations.
struct CalorieBarFill: View {

    let values: EnergyGraphValues
    let side: EnergyGraphValues.Side
    let palette: CalorieGraphPalette
    let rendering: CalorieGraphRendering

    var body: some View {
        switch rendering {
            case .live:
                AnimatedCalorieGraph(values: values) { values in
                    CalorieBarFillDrawing(values: values, side: side, palette: palette)
                }

            case .widget:
                CalorieBarFillDrawing(values: values, side: side, palette: palette)
        }
    }

}
