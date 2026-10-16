import Foundation
import SwiftUI

@main
struct EnergyGraphTransitions {

    static func main() {

        let early = EnergyBalance(active: 1, resting: 2, consumed: 2)
        let midnight = EnergyBalance(active: 1, resting: 2, restingRemaining: 1_714, consumed: 2)
        let start = EnergyGraphValues(early)
        let end = EnergyGraphValues(midnight)
        let progress = 0.1
        let frame = interpolate(start, end, progress: progress)
        let actual = frame.consumedSegments[0].range.upperBound
        let expected = start.consumedSegments[0].range.upperBound * (1 - progress)
            + end.consumedSegments[0].range.upperBound * progress
        guard abs(actual - expected) < 0.000_001 else {
            print("FAIL: early-day endpoint at 10% is \(actual), expected \(expected). Visible travel happens at once.")
            exit(1)
        }
        print("PASS: extreme Now/Midnight geometry spreads movement across the transition.")

        let snapshots = [
            early, midnight,
            EnergyBalance(active: 692, resting: 494, consumed: 1_703),
            EnergyBalance(active: 692, resting: 494, restingRemaining: 1_505, consumed: 1_703),
            EnergyBalance(active: 170, resting: 981, consumed: 1_772),
            EnergyBalance(active: 170, resting: 981, restingRemaining: 1_338, consumed: 1_772),
            EnergyBalance(active: 211, resting: 2_123, consumed: 2_883),
            EnergyBalance(active: 0, resting: 0, consumed: 0),
            EnergyBalance(active: 0, resting: 0, restingRemaining: 2_000, consumed: 0),
            EnergyBalance(active: 0, resting: 0, consumed: 10_000),
            EnergyBalance(active: 9, resting: 90, restingRemaining: 901, consumed: 999),
            EnergyBalance(active: 1_000, resting: 1_000, consumed: 1_500)
        ]
        for energy in snapshots {
            let values = EnergyGraphValues(energy)
            let scale = Double(energy.graphTotal)
            let expected = scale > 0 ? Double(energy.consumed) / scale : 0
            check(values.consumedSegments[0].range.upperBound == expected, "Settled consumed proportion changed")
            let burned = values.burnedSegments
            let expectedBurned = scale > 0 ? Double(energy.burned) / scale : 0
            check(burned[2].range.upperBound == expectedBurned, "Settled burned proportion changed")
            check(burned.map(\.value) == [Double(energy.active), Double(energy.resting),
                Double(energy.restingRemaining), Double(max(0, energy.consumed - energy.burned))],
                "Settled label values changed")
        }
        let graphSnapshots = snapshots.map(EnergyGraphValues.init)
        var transitions = 0
        for start in graphSnapshots {
            for end in graphSnapshots {
                for step in 0...100 {
                    let progress = Double(step) / 100
                    let frame = interpolate(start, end, progress: progress)
                    for side in [EnergyGraphValues.Side.burned, .consumed] {
                        let before = start.segments(for: side)
                        let after = end.segments(for: side)
                        let current = frame.segments(for: side)
                        check(current.map(\.id) == before.map(\.id), "Segment identities changed")
                        for index in current.indices {
                            let expectedStart = before[index].range.lowerBound * (1 - progress)
                                + after[index].range.lowerBound * progress
                            let expectedEnd = before[index].range.upperBound * (1 - progress)
                                + after[index].range.upperBound * progress
                            check(abs(current[index].range.lowerBound - expectedStart) < 0.000_001,
                                  "Segment leading boundary jumped at \(progress)")
                            check(abs(current[index].range.upperBound - expectedEnd) < 0.000_001,
                                  "Segment trailing boundary jumped at \(progress)")
                        }
                    }
                }
                // Interrupted animations and spring extrapolation must keep every range drawable.
                for progress in [-0.2, -0.01, 1.01, 1.2] {
                    let frame = interpolate(start, end, progress: progress)
                    for side in [EnergyGraphValues.Side.burned, .consumed] {
                        let segments = frame.segments(for: side)
                        for segment in segments {
                            check(segment.range.lowerBound.isFinite && segment.range.upperBound.isFinite,
                                  "Nonfinite segment endpoint")
                            check(segment.range.lowerBound >= 0 && segment.range.upperBound <= 1,
                                  "Extrapolated segment escaped the graph")
                        }
                        for pair in zip(segments, segments.dropFirst()) {
                            check(pair.0.range.upperBound == pair.1.range.lowerBound, "Segments separated or crossed")
                        }
                    }
                }
                let interrupted = interpolate(start, end, progress: 0.37)
                let returning = interpolate(interrupted, start, progress: 0)
                check(returning == interrupted, "Retargeting changed the current presentation")
                transitions += 1
            }
        }
        print("PASS: \(transitions) transitions cover both directions, empty graphs, crossovers, and digit-width changes.")
        print("PASS: interrupted transitions and extrapolated geometry stay ordered and bounded.")
    }

    static func interpolate(_ start: EnergyGraphValues, _ end: EnergyGraphValues, progress: Double) -> EnergyGraphValues {

        var result = start
        var delta = end.animatableData - start.animatableData
        delta.scale(by: progress)
        result.animatableData = start.animatableData + delta
        return result
    }

    static func check(_ condition: Bool, _ message: String) {
        guard condition else {
            print("FAIL: \(message)")
            exit(1)
        }
    }

}
