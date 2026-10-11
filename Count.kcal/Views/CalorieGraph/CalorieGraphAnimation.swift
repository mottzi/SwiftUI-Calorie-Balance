import SwiftUI

/// Shared motion for calorie proportions and value labels.
struct CalorieGraphAnimation: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let values: EnergyGraphValues
    var duration: TimeInterval = 0.5

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? nil : .bouncy(duration: min(max(duration, 0), 2)),
            value: values
        )
    }

}
