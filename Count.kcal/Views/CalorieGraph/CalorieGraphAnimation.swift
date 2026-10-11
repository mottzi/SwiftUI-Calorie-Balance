import SwiftUI

/// Shared motion for calorie proportions and value labels.
struct CalorieGraphAnimation: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let values: EnergyGraphValues
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? nil : .bouncy(duration: min(max(duration, 0), 2)),
            value: values
        )
    }

}

extension CalorieGraphAnimation {

    static let defaultDuration: TimeInterval = 0.5

}
