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
        // animate the scale with the totals so graph endpoints do not stop at the balance crossover
        graphScale = max(active + resting + restingRemaining, consumed)
        presence = graphScale > 0 ? 1 : 0
    }

    /// Active, recorded resting, projected resting, and unused shares of the common scale.
    var burnedSegments: [Segment] {
        // Springs may overshoot zero; keep the drawn partition ordered without changing animation data.
        let activeEnergy = max(0, active)
        let restingEnergy = max(0, resting)
        let projectedEnergy = max(0, restingRemaining)
        let recordedEnergy = activeEnergy + restingEnergy
        let burnedEnergy = recordedEnergy + projectedEnergy
        let activeEnd = ratio(of: activeEnergy)
        let restingEnd = ratio(of: recordedEnergy)
        let burnedEnd = ratio(of: burnedEnergy)
        return [
            Segment(id: .active, value: activeEnergy, range: 0...activeEnd),
            Segment(id: .resting, value: restingEnergy, range: activeEnd...restingEnd),
            Segment(id: .prediction, value: projectedEnergy, range: restingEnd...burnedEnd),
            Segment(id: .empty, value: max(0, consumed - burnedEnergy), range: burnedEnd...1)
        ]
    }

    /// Consumed and unused shares of the same scale as burned energy.
    var consumedSegments: [Segment] {
        let consumedEnergy = max(0, consumed)
        let burnedEnergy = max(0, active) + max(0, resting) + max(0, restingRemaining)
        let consumedEnd = ratio(of: consumedEnergy)
        return [
            Segment(id: .consumed, value: consumedEnergy, range: 0...consumedEnd),
            Segment(id: .empty, value: max(0, burnedEnergy - consumedEnergy), range: consumedEnd...1)
        ]
    }

    /// Returns the ordered segments for one side of the calorie balance.
    func segments(for side: Side) -> [Segment] {
        switch side {
            case .burned: burnedSegments
            case .consumed: consumedSegments
        }
    }

}

extension EnergyGraphValues {

    private func ratio(of amount: Double) -> Double {
        return graphScale > 0 ? min(max(amount / graphScale, 0), 1) * min(max(presence, 0), 1) : 0
    }

    struct Segment: Identifiable {
        let id: Part
        let value: Double
        let range: ClosedRange<Double>
    }

    enum Side {
        case burned
        case consumed
    }

    enum Part: String, Hashable {
        case active
        case resting
        case prediction
        case consumed
        case empty
    }

}
