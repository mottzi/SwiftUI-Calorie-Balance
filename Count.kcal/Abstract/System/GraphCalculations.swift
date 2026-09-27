/// Energy proportions shared by app, widget, and complication ring graphs.
struct GraphCalculations {

    let sample: HealthData

    /// Active energy as a share of the larger current energy total.
    var activeNow: Double { ratio(sample.burnedActive, of: maxNow) }

    /// Combined active and resting energy as a share of the current total.
    var passiveNow: Double { ratio(sample.burnedActive + sample.burnedPassive, of: maxNow) }

    /// Consumed energy as a share of the current total.
    var consumedNow: Double { ratio(sample.consumed, of: maxNow) }

    /// Active energy as a share of the larger midnight energy total.
    var activeMidnight: Double { ratio(sample.burnedActiveMidnight, of: maxMidnight) }

    /// Active and recorded resting energy as a share of the midnight total.
    var passiveMidnight: Double {
        ratio(sample.burnedActiveMidnight + sample.burnedPassive, of: maxMidnight)
    }

    /// Active and projected resting energy as a share of the midnight total.
    var passiveFutureMidnight: Double {
        ratio(sample.burnedActiveMidnight + sample.burnedPassive + sample.burnedPassiveRemaining, of: maxMidnight)
    }

    /// Consumed energy as a share of the midnight total.
    var consumedMidnight: Double { ratio(sample.consumed, of: maxMidnight) }

}

extension GraphCalculations {

    private var maxNow: Int { max(sample.burnedActive + sample.burnedPassive, sample.consumed) }

    private var maxMidnight: Int {
        max(sample.burnedActiveMidnight + sample.burnedPassive + sample.burnedPassiveRemaining, sample.consumed)
    }

    /// Returns zero for an empty graph.
    private func ratio(_ value: Int, of total: Int) -> Double {
        total == 0 ? 0 : Double(value) / Double(total)
    }

}
