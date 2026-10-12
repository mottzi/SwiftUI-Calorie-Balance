import Foundation

@main
struct CalorieLoadingSemantics {

    static func main() {

        let pending = CalorieDataState(energy: nil, balanceGoal: 500, isLoss: true)
        guard pending == .loading else {
            print("FAIL: unresolved HealthKit estimates show the incomplete-data state at launch")
            exit(1)
        }
        precondition(CalorieDataState(energy: 0, balanceGoal: 500, isLoss: true) == .incomplete)
        precondition(CalorieDataState(energy: 0, balanceGoal: 500, isLoss: false) == .incomplete)
        precondition(CalorieDataState(energy: 2500, balanceGoal: 500, isLoss: true) == .ready)
        precondition(CalorieDataState(energy: 2500, balanceGoal: 500, isLoss: false) == .ready)
        precondition(CalorieDataState(energy: 400, balanceGoal: 500, isLoss: true) == .incomplete)
        precondition(CalorieDataState(energy: nil, balanceGoal: -1, isLoss: true) == .incomplete)
        print("Calorie loading checks passed")
    }

}
