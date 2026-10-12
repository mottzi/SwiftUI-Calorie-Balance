/// Separates unresolved energy estimates from confirmed missing data or invalid goals.
enum CalorieDataState: Equatable {

    case loading
    case ready
    case incomplete

    init(energy: Int?, balanceGoal: Int, isLoss: Bool) {

        guard balanceGoal >= 0 else { self = .incomplete; return }
        guard let energy else { self = .loading; return }
        guard energy > 0 else { self = .incomplete; return }
        let allowance = energy + (isLoss ? -balanceGoal : balanceGoal)
        self = allowance > 0 ? .ready : .incomplete
    }

}
