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
            switch rendering {
                case .live:
                    AnimatedCalorieGraph(values: values) { values in
                        CalorieCircleDrawing(values: values, configuration: configuration, palette: palette)
                    }

                case .widget:
                    CalorieCircleDrawing(values: values, configuration: configuration, palette: palette)
            }
        }
        .modifier(CalorieGraphAnimation(values: values, duration: configuration.animationDuration))
        .graphColorAppearance()
        .accessibilityHidden(true)
    }

}
