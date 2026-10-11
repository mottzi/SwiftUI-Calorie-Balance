import SwiftUI

@Animatable
/// Continuous energy values with an animated scale for burned and consumed energy.
struct EnergyGraphValues: Equatable {

    var active: Double
    var resting: Double
    var restingRemaining: Double
    var consumed: Double
    private var graphScale: Double
    private var presence: Double

    init(_ energy: EnergyBalance) {
        active = Double(max(0, energy.active))
        resting = Double(max(0, energy.resting))
        restingRemaining = Double(max(0, energy.restingRemaining))
        consumed = Double(max(0, energy.consumed))
        // animate the scale with the totals so ring endpoints do not stop at the balance crossover
        graphScale = max(active + resting + restingRemaining, consumed)
        presence = graphScale > 0 ? 1 : 0
    }

    /// Active, recorded resting, projected resting, and unused shares of the common scale.
    var burnedSegments: [Segment] {
        // Springs may overshoot zero; keep the drawn partition ordered without changing animation data.
        let activeEnergy = max(0, active)
        let recordedEnergy = activeEnergy + max(0, resting)
        let activeEnd = ratio(of: activeEnergy)
        let restingEnd = ratio(of: recordedEnergy)
        let burnedEnd = ratio(of: recordedEnergy + max(0, restingRemaining))
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

    private func ratio(of amount: Double) -> Double {
        return graphScale > 0 ? min(max(amount / graphScale, 0), 1) * min(max(presence, 0), 1) : 0
    }

    struct Segment: Identifiable {
        let id: Part
        let range: ClosedRange<Double>
    }

    enum Part: String, Hashable {
        case active
        case resting
        case prediction
        case consumed
        case empty
    }

}
