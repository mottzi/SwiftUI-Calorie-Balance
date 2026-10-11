import SwiftUI

/// Coordinated energy transitions for live graphs and widgets.
struct CalorieGraphDrawing<Drawing: View>: View {

    let values: EnergyGraphValues
    let rendering: CalorieGraphRendering
    @ViewBuilder let drawing: (EnergyGraphValues) -> Drawing

    var body: some View {
        switch rendering {
            case .live: AnimatedDrawing(values: values, drawing: drawing)
            case .widget: drawing(values)
        }
    }

}

extension CalorieGraphDrawing {

    /// Synchronized segment motion from one set of interpolated energy values.
    private struct AnimatedDrawing: View, Animatable {

        var values: EnergyGraphValues
        @ViewBuilder let drawing: (EnergyGraphValues) -> Drawing

        var body: some View {
            drawing(values)
                .transaction {
                    $0.animation = nil
                    $0.disablesAnimations = true
                }
        }

        /// Interpolates segment values and their common scale together.
        var animatableData: EnergyGraphValues.AnimatableData {
            get { values.animatableData }
            set { values.animatableData = newValue }
        }

    }

}
