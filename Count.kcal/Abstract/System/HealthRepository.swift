import HealthKit

/// Shared settings policy and calculations over HealthKit or sample measurements.
@MainActor
final class HealthRepository {

    private let injectedSource: (any HealthDataSource)?
    private lazy var healthKit = HealthKitDataSource()

    /// Omit the source for app mode selection, or inject one for focused tests.
    init(source: (any HealthDataSource)? = nil) { injectedSource = source }

    /// Fetches one daily value with fixed settings and calendar bounds.
    func fetchDailySnapshot(for date: Date, settings: Settings = .shared, now: Date = .now) async -> HealthData {

        // capture the policy and query range before any HealthKit suspension
        let measuredData = dataSource
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: dayStart)!
        let usesCustomEnergy = settings.usesCustomEnergy
        let energyUnit = settings.energyUnit
        let customActive = settings.customCalActive
        let customPassive = settings.customCalPassive
        let isToday = calendar.isDate(date, inSameDayAs: now)
        var snapshot = HealthData.empty(for: dayStart)
        snapshot.usesMeasuredActiveAtMidnight = !usesCustomEnergy

        if !Task.isCancelled {
            let energy: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
            let grams = HKUnit.gram()
            let count = HKUnit.count()

            // run independent queries against the same captured day
            async let active = dailySum(measuredData, .activeEnergyBurned, from: dayStart, to: dayEnd, unit: energy)
            async let passive = dailySum(measuredData, .basalEnergyBurned, from: dayStart, to: dayEnd, unit: energy)
            async let passiveAverage = weeklyAverage(
                measuredData, .basalEnergyBurned,
                from: weekStart,
                to: dayStart,
                unit: energy
            )
            async let consumed = dailySum(measuredData, .dietaryEnergyConsumed, from: dayStart, to: dayEnd, unit: energy)
            async let protein = dailySum(measuredData, .dietaryProtein, from: dayStart, to: dayEnd, unit: grams)
            async let carbs = dailySum(measuredData, .dietaryCarbohydrates, from: dayStart, to: dayEnd, unit: grams)
            async let fats = dailySum(measuredData, .dietaryFatTotal, from: dayStart, to: dayEnd, unit: grams)
            async let steps = dailySum(measuredData, .stepCount, from: dayStart, to: dayEnd, unit: count)
            let values = await (active, passive, passiveAverage, consumed, protein, carbs, fats, steps)
            guard !Task.isCancelled else { return snapshot }

            snapshot.consumed = values.3
            snapshot.protein = values.4
            snapshot.carbs = values.5
            snapshot.fats = values.6
            snapshot.steps = values.7
            snapshot.burnedActive = values.0
            snapshot.burnedPassive = values.1
            snapshot.burnedPassive7 = values.2
        }

        if usesCustomEnergy {
            let progress = isToday
                ? min(max(now.timeIntervalSince(dayStart) / dayEnd.timeIntervalSince(dayStart), 0), 1)
                : 1
            snapshot.burnedActive = Int((Double(customActive) * progress).rounded())
            snapshot.burnedPassive = Int((Double(customPassive) * progress).rounded())
            snapshot.burnedActive7 = customActive
            snapshot.burnedPassive7 = customPassive
        }

        snapshot.lastDataSync = now
        return snapshot
    }

}

extension HealthRepository {

    var revision: String { HealthDataMode.currentRevision }

    /// Loads daily energy balances for a bounded streak count with fixed settings.
    func fetchStreakEnergy(
        endingOn date: Date,
        days: Int,
        source: Settings.DataSources,
        energyUnit: Settings.EnergyUnit,
        customActive: Int,
        customPassive: Int
    ) async -> [EnergyBalance] {

        guard days > 0 else { return [] }
        let usesCustomEnergy = Settings.usesCustomEnergy(for: source)
        let measuredData = dataSource
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let start = calendar.date(byAdding: .day, value: -days, to: end)!
        let unit: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()

        var active: [Date: Double] = [:]
        var passive: [Date: Double] = [:]
        var consumed: [Date: Double] = [:]
        if !Task.isCancelled {
            async let activeSums = measuredData.dailySums(.activeEnergyBurned, from: start, to: end, unit: unit)
            async let passiveSums = measuredData.dailySums(.basalEnergyBurned, from: start, to: end, unit: unit)
            async let consumedSums = measuredData.dailySums(.dietaryEnergyConsumed, from: start, to: end, unit: unit)
            let sums = await (activeSums, passiveSums, consumedSums)
            active = sums.0
            passive = sums.1
            consumed = sums.2
        }

        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset - 1, to: end)!
            let burnedActive = usesCustomEnergy ? customActive : Int(active[day, default: 0].rounded())
            let burnedPassive = usesCustomEnergy ? customPassive : Int(passive[day, default: 0].rounded())
            let intake = Int(consumed[day, default: 0].rounded())
            return EnergyBalance(active: burnedActive, resting: burnedPassive, consumed: intake)
        }
    }

    /// Loads daily weight averages for the chart period ending on the given date.
    func fetchInitialAvgWeightData(for date: Date, weightUnit: Settings.WeightUnit) async -> [WeightChartData] {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        let dayStart = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Calendar.current.startOfDay(for: date)
        )!.lastMonday
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!

        let values = await dataSource.weights(from: dayStart, to: dayEnd, unit: unit)
        return values.map { WeightChartData(date: $0.date, weightAvg: $0.weightAvg.map { ($0 * 10).rounded() / 10 }) }
    }

    /// Returns the latest weight value and its sample date.
    func fetchLatestWeightData(for date: Date, weightUnit: Settings.WeightUnit) async -> (Double?, Date?) {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        let (weight, sampleDate) = await dataSource.latestWeight(before: dayEnd, unit: unit)
        return (weight.map { ($0 * 10).rounded() / 10 }, sampleDate)
    }

    /// Sample mode never requests HealthKit authorization.
    func requestPermission() async -> Bool { await dataSource.requestPermission() }

    /// Returns the prior seven days' average for settings and legacy callers.
    func cumDataWeek(
        fetch dataType: HKQuantityTypeIdentifier,
        for date: Date,
        energyUnit: Settings.EnergyUnit = Settings.shared.energyUnit
    ) async -> Int {

        let measuredData = dataSource
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let unit: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
        return await weeklyAverage(measuredData, dataType, from: start, to: end, unit: unit)
    }

}

extension HealthRepository {

    private func dailySum(
        _ source: any HealthDataSource,
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async -> Int {
        let sums = await source.dailySums(type, from: start, to: end, unit: unit)
        return Int(sums[start, default: 0].rounded())
    }

    private func weeklyAverage(
        _ source: any HealthDataSource,
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async -> Int {
        let sums = await source.dailySums(type, from: start, to: end, unit: unit)
        // The statistics collection can include the bucket at end. Exclude it.
        let total = sums.filter { $0.key >= start && $0.key < end }.values.reduce(0, +)
        return Int((total / 7).rounded())
    }

}

extension HealthRepository {

    private var dataSource: any HealthDataSource {
        if let injectedSource { return injectedSource }
        #if DEBUG && os(iOS)
        if HealthDataMode.isSampleDataEnabled { return SampleHealthDataSource() }
        #endif
        return healthKit
    }

}

extension HealthRepository {

    static let shared = HealthRepository()

}
