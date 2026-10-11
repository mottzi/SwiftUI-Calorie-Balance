import SwiftUI

/// Color and opacity for each energy part and the unused ring.
struct CalorieCirclePalette {

    var active: Fill
    var resting: Fill
    var prediction: Fill
    var consumed: Fill
    var empty: Fill

    init(burned: Color, consumed: Color, empty: Color) {
        active = Fill(color: burned, brightness: BrightnessLevel.primary.amount(in: .circlegraphMidnight))
        resting = Fill(color: burned, brightness: BrightnessLevel.secondary.amount(in: .circlegraphMidnight))
        prediction = Fill(color: burned, brightness: BrightnessLevel.tertiary.amount(in: .circlegraphMidnight))
        self.consumed = Fill(color: consumed, brightness: BrightnessLevel.primary.amount(in: .bargraph))
        self.empty = Fill(color: empty, brightness: BrightnessLevel.primary.amount(in: .bargraph))
    }

    /// Selects the appearance of a stable energy part.
    func fill(for part: EnergyGraphValues.Part) -> Fill {
        switch part {
            case .active: active
            case .resting: resting
            case .prediction: prediction
            case .consumed: consumed
            case .empty: empty
        }
    }

    struct Fill {
        var color: Color
        var brightness: Double
        var opacity: Double = 1
    }

}
