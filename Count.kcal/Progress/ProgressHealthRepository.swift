import HealthKit

extension HealthRepository {

    /// Reads completed calendar days with the selected energy policy and no projected burn.
    func fetchProgressEnergy(before today: Date, days: Int = 30, policy: ProgressPolicy) async throws -> [ProgressDay] {

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: today)!
        let source = dataSource
        let unit: HKUnit = policy.energyUnit == "kJ" ? .jouleUnit(with: .kilo) : .kilocalorie()
        async let food = source.energySums(.dietaryEnergyConsumed, from: start, to: today, unit: unit)
        var active: [Date: Double] = [:]
        var resting: [Date: Double] = [:]
        if !policy.customEnergy {
            async let activeSums = source.energySums(.activeEnergyBurned, from: start, to: today, unit: unit)
            async let restingSums = source.energySums(.basalEnergyBurned, from: start, to: today, unit: unit)
            (active, resting) = try await (activeSums, restingSums)
        }
        let consumed = try await food
        try Task.checkCancellation()
        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return ProgressDay(
                date: date,
                active: policy.customEnergy ? Double(policy.customActive) : active[date, default: 0],
                resting: policy.customEnergy ? Double(policy.customResting) : resting[date, default: 0],
                food: consumed[date, default: 0],
                usesCustomEnergy: policy.customEnergy
            )
        }
    }

    /// Reads unrounded daily means for two consecutive thirty-day weight periods.
    func fetchProgressWeights(before today: Date, policy: ProgressPolicy) async throws -> [Date: Double] {

        let start = Calendar.current.date(byAdding: .day, value: -60, to: today)!
        let unit: HKUnit = policy.weightUnit == "lbs" ? .pound() : .gramUnit(with: .kilo)
        let weights = try await dataSource.weights(from: start, to: today, unit: unit)
        return Dictionary(weights.compactMap { day in
            day.weightAvg.map { (day.date, $0) }
        }, uniquingKeysWith: { _, latest in latest })
    }

}
