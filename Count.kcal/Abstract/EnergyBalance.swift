import Foundation

/// Energy totals and graph proportions for one point in the day.
struct EnergyBalance: Equatable {

    let active: Int
    let resting: Int

    /// Resting energy expected after the last recorded sample.
    let restingRemaining: Int
    let consumed: Int

    init(
        active: Int,
        resting: Int,
        restingRemaining: Int = 0,
        consumed: Int
    ) {
        self.active = active
        self.resting = resting
        self.restingRemaining = restingRemaining
        self.consumed = consumed
    }

    /// Total recorded and projected energy burned.
    var burned: Int { active + resting + restingRemaining }

    /// Positive values are a deficit; negative values are a surplus.
    var balance: Int { burned - consumed }

    /// Both displayed energy totals are empty.
    var isEmpty: Bool { burned == 0 && consumed == 0 }

    /// Larger side of the graph, or zero if both totals are empty.
    var graphTotal: Int { max(burned, consumed) }

    /// Tests the selected weight goal against the signed balance.
    func meetsGoal(_ goal: Int, isLoss: Bool) -> Bool {
        isLoss ? balance >= goal : balance <= -goal
    }

    /// Returns an energy amount's share of the graph, or zero for an empty graph.
    func ratio(of amount: Int) -> Double {
        graphTotal == 0 ? 0 : Double(amount) / Double(graphTotal)
    }

}
