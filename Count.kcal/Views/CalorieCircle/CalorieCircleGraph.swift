import SwiftUI

/// Burned and consumed rings with a shared scale and stable projected-resting segment.
struct CalorieCircleGraph: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let energy: EnergyBalance
    var configuration = CalorieCircleConfiguration()
    let palette: CalorieCirclePalette
    var rendering: Rendering = .live

    var body: some View {
        let values = EnergyGraphValues(energy)
        Group {
            switch rendering {
                case .live:
                    AnimatedCalorieCircle(values: values, configuration: configuration, palette: palette)

                case .widget:
                    CalorieCircleDrawing(values: values, configuration: configuration, palette: palette)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: min(max(configuration.animationDuration, 0), 2)),
            value: values
        )
        .graphColorAppearance()
        .accessibilityHidden(true)
    }

    enum Rendering {
        case live
        case widget
    }

}
