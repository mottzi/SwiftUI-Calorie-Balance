import SwiftUI

/// Recalculates both rings and their gaps from the current animated energy values.
struct AnimatedCalorieCircle: View, Animatable {

    var values: EnergyGraphValues
    let configuration: CalorieCircleConfiguration
    let palette: CalorieCirclePalette

    var body: some View {
        CalorieCircleDrawing(values: values, configuration: configuration, palette: palette)
            .transaction {
                $0.animation = nil
                $0.disablesAnimations = true
            }
    }

    var animatableData: EnergyGraphValues.AnimatableData {
        get { values.animatableData }
        set { values.animatableData = newValue }
    }

}
