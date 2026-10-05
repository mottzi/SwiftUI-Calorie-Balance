import Foundation

/// Recorded amount and progress toward a positive daily goal.
struct ComplicationGoalProgress: Equatable {

    let amount: Int
    let goal: Int

    var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(amount) / Double(goal), 0), 1)
    }

    var remaining: Int? {
        goal > 0 ? max(goal - amount, 0) : nil
    }

    var isComplete: Bool { goal > 0 && amount >= goal }

}

/// Food allowance after the weight goal adjusts the midnight energy estimate.
struct ComplicationCalorieBudget: Equatable {

    let allowance: Int
    let consumed: Int

    init(burned: Int, consumed: Int, balanceGoal: Int, isLoss: Bool) {
        allowance = burned > 0 ? max(burned + (isLoss ? -balanceGoal : balanceGoal), 0) : 0
        self.consumed = max(consumed, 0)
    }

    var remaining: Int? { allowance > 0 ? allowance - consumed : nil }

    var progress: ComplicationGoalProgress { ComplicationGoalProgress(amount: consumed, goal: allowance) }

}
