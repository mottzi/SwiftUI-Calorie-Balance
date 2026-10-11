import SwiftUI

@Animatable
/// Continuous energy values with one scale for burned and consumed energy.
struct EnergyGraphValues: Equatable {

    var active: Double
    var resting: Double
    var restingRemaining: Double
    var consumed: Double
    private var presence: Double

    init(_ energy: EnergyBalance) {
        active = Double(max(0, energy.active))
        resting = Double(max(0, energy.resting))
        restingRemaining = Double(max(0, energy.restingRemaining))
        consumed = Double(max(0, energy.consumed))
        presence = max(active + resting + restingRemaining, consumed) > 0 ? 1 : 0
    }

    /// Active, recorded resting, projected resting, and unused shares of the common scale.
    var burnedSegments: [Segment] {
        let activeEnd = ratio(of: active)
        let restingEnd = ratio(of: active + resting)
        let burnedEnd = ratio(of: burned)
        return [
            Segment(id: .active, range: 0...activeEnd),
            Segment(id: .resting, range: activeEnd...restingEnd),
            Segment(id: .prediction, range: restingEnd...burnedEnd),
            Segment(id: .empty, range: burnedEnd...1)
        ]
    }

    /// Consumed and unused shares of the same scale as burned energy.
    var consumedSegments: [Segment] {
        let consumedEnd = ratio(of: consumed)
        return [
            Segment(id: .consumed, range: 0...consumedEnd),
            Segment(id: .empty, range: consumedEnd...1)
        ]
    }

}

extension EnergyGraphValues {

    private var burned: Double { active + resting + restingRemaining }

    private func ratio(of amount: Double) -> Double {
        let total = max(burned, consumed)
        return total > 0 ? min(max(amount / total, 0), 1) * presence : 0
    }

    struct Segment: Identifiable {
        let id: Part
        let range: ClosedRange<Double>
    }

    enum Part: Hashable {
        case active
        case resting
        case prediction
        case consumed
        case empty
    }

}
