import Foundation

@main
struct ComplicationGoalSemantics {

    static func main() {
        let loss = ComplicationCalorieBudget(burned: 2950, consumed: 1810, balanceGoal: 500, isLoss: true)
        precondition(loss.allowance == 2450 && loss.remaining == 640)
        let gain = ComplicationCalorieBudget(burned: 2950, consumed: 1810, balanceGoal: 500, isLoss: false)
        precondition(gain.allowance == 3450 && gain.remaining == 1640)
        let over = ComplicationCalorieBudget(burned: 2200, consumed: 2400, balanceGoal: 500, isLoss: true)
        precondition(over.remaining == -700 && over.progress.fraction == 1)
        let missing = ComplicationCalorieBudget(burned: 0, consumed: 200, balanceGoal: 500, isLoss: false)
        precondition(missing.remaining == nil && missing.progress.fraction == 0)
        let impossible = ComplicationCalorieBudget(burned: 300, consumed: 100, balanceGoal: 500, isLoss: true)
        precondition(impossible.allowance == 0 && impossible.remaining == nil)

        let kilojoules = ComplicationCalorieBudget(burned: 12343, consumed: 7573, balanceGoal: 2092, isLoss: true)
        precondition(kilojoules.remaining == 2678)
        let negative = ComplicationCalorieBudget(burned: 2200, consumed: -1, balanceGoal: 500, isLoss: true)
        precondition(negative.consumed == 0)

        let steps = ComplicationGoalProgress(amount: 7240, goal: 10000)
        precondition(steps.fraction == 0.724 && steps.remaining == 2760 && !steps.isComplete)
        let reached = ComplicationGoalProgress(amount: 10000, goal: 10000)
        precondition(reached.fraction == 1 && reached.remaining == 0 && reached.isComplete)
        let exceeded = ComplicationGoalProgress(amount: 12000, goal: 10000)
        precondition(exceeded.fraction == 1 && exceeded.remaining == 0 && exceeded.isComplete)
        for goal in [0, -1] {
            let unset = ComplicationGoalProgress(amount: 100, goal: goal)
            precondition(unset.fraction == 0 && unset.remaining == nil && !unset.isComplete)
        }
        let empty = ComplicationGoalProgress(amount: 0, goal: 140)
        precondition(empty.fraction == 0 && empty.remaining == 140)
        let protein = ComplicationGoalProgress(amount: 106, goal: 140)
        precondition(protein.remaining == 34 && abs(protein.fraction - 106.0 / 140) < 0.00001)
        print("Complication goal checks passed")
    }

}
