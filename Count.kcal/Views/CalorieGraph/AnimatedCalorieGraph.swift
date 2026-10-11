import SwiftUI

/// Recalculates graph geometry from one set of interpolated energy values.
struct AnimatedCalorieGraph<Drawing: View>: View, Animatable {

    var values: EnergyGraphValues
    @ViewBuilder let drawing: (EnergyGraphValues) -> Drawing

    var body: some View {
        drawing(values)
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
