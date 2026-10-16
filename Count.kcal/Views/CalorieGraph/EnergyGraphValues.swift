import SwiftUI

@Animatable
/// Calorie values and normalized endpoints that move together between graph snapshots.
struct EnergyGraphValues: Equatable {

    var active: Double
    var resting: Double
    var restingRemaining: Double
    var consumed: Double
    private var activeEndpoint: Double
    private var restingEndpoint: Double
    private var burnedEndpoint: Double
    private var consumedEndpoint: Double

    init(_ energy: EnergyBalance) {
        active = Double(max(0, energy.active))
        resting = Double(max(0, energy.resting))
        restingRemaining = Double(max(0, energy.restingRemaining))
        consumed = Double(max(0, energy.consumed))
        let burned = active + resting + restingRemaining
        let scale = max(burned, consumed)
        // Normalize each snapshot once. Dividing by an interpolated calorie scale
        // compresses nearly all visible movement into one end of extreme changes.
        activeEndpoint = scale > 0 ? active / scale : 0
        restingEndpoint = scale > 0 ? (active + resting) / scale : 0
        burnedEndpoint = scale > 0 ? burned / scale : 0
        consumedEndpoint = scale > 0 ? consumed / scale : 0
    }

    /// Active, recorded resting, projected resting, and unused shares of the common scale.
    var burnedSegments: [Segment] {
        // Springs may overshoot zero; keep the drawn partition ordered without changing animation data.
        let activeEnergy = max(0, active)
        let restingEnergy = max(0, resting)
        let projectedEnergy = max(0, restingRemaining)
        let burnedEnergy = activeEnergy + restingEnergy + projectedEnergy
        let activeEnd = min(max(activeEndpoint, 0), 1)
        let restingEnd = min(max(restingEndpoint, activeEnd), 1)
        let burnedEnd = min(max(burnedEndpoint, restingEnd), 1)
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
        let consumedEnd = min(max(consumedEndpoint, 0), 1)
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

    /// One stable energy part, its calorie value, and its share of the graph scale.
    struct Segment: Identifiable {
        let id: Part
        let value: Double
        let range: ClosedRange<Double>
    }

    /// Burned or consumed energy on the common graph scale.
    enum Side {
        case burned
        case consumed
    }

    /// Stable segment identities, including projected resting energy and unused space.
    enum Part: String, Hashable {
        case active
        case resting
        case prediction
        case consumed
        case empty
    }

}
