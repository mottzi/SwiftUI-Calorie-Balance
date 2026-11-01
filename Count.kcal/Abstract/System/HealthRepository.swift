import HealthKit
import Observation

@MainActor
@Observable
/// Shared settings policy and calculations over HealthKit or sample measurements.
final class HealthRepository {

    @ObservationIgnored private let injectedSource: (any HealthDataSource)?
    @ObservationIgnored private lazy var healthKit = HealthKitDataSource()

    #if DEBUG && (os(iOS) || os(watchOS))
    private var developmentRevision = 0
    @ObservationIgnored private var developmentSourceRevision: String?
    @ObservationIgnored private var developmentDays: [Date: [HKQuantityTypeIdentifier: HKQuantity]] = [:]
    #endif

    /// Omit the source for app mode selection, or inject one for focused tests.
    init(source: (any HealthDataSource)? = nil) { injectedSource = source }

    /// Fetches one daily value with fixed settings and calendar bounds.
    func fetchDailySnapshot(for date: Date, settings: Settings? = nil, now: Date = .now) async -> HealthData {

        await fetchDailySnapshot(for: date, policy: HealthSnapshotPolicy(settings: settings ?? .shared), now: now)
    }

    /// Applies one fixed policy to every measurement in the daily read.
    func fetchDailySnapshot(for date: Date, policy: HealthSnapshotPolicy, now: Date = .now) async -> HealthData {

        // capture the policy and query range before any HealthKit suspension
        let measuredData = snapshotSource(policy: policy, now: now)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: dayStart)!
        let usesCustomEnergy = policy.usesCustomEnergy
        let energyUnit = policy.energyUnit
        let customActive = policy.customActive
        let customPassive = policy.customPassive
        let isToday = calendar.isDate(date, inSameDayAs: now)
        var snapshot = HealthData.empty(for: dayStart)
        snapshot.usesMeasuredActiveAtMidnight = !usesCustomEnergy
        snapshot.isSampleData = injectedSource == nil && HealthDataMode.isSampleDataEnabled

        do {
            try Task.checkCancellation()
            let energy: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
            let grams = HKUnit.gram()
            let count = HKUnit.count()

            // run independent queries against the same captured day
            async let active = usesCustomEnergy ? 0 : try await dailySum(
                measuredData, .activeEnergyBurned,
                from: dayStart,
                to: dayEnd,
                unit: energy
            )
            async let passive = usesCustomEnergy ? 0 : try await dailySum(
                measuredData, .basalEnergyBurned,
                from: dayStart,
                to: dayEnd,
                unit: energy
            )
            async let passiveAverage = usesCustomEnergy ? 0 : try await weeklyAverage(
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
            let values = try await (active, passive, passiveAverage, consumed, protein, carbs, fats, steps)
            try Task.checkCancellation()

            snapshot.consumed = values.3
            snapshot.protein = values.4
            snapshot.carbs = values.5
            snapshot.fats = values.6
            snapshot.steps = values.7
            snapshot.burnedActive = values.0
            snapshot.burnedPassive = values.1
            snapshot.burnedPassive7 = values.2
        } catch {
            var unavailable = HealthData.unavailable(for: dayStart)
            unavailable.isSampleData = snapshot.isSampleData
            return unavailable
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

    var usesMarketingSamples: Bool { injectedSource == nil && HealthDataMode.isMarketingDataEnabled }
    var usesSampleMeasurements: Bool { injectedSource == nil && HealthDataMode.isSampleDataEnabled }

    /// Invalidates consumers after a source change or a temporary measurement edit.
    var revision: String {

        // observe local changes and read shared defaults again for extension updates
        _ = HealthDataMode.shared.revision
        #if DEBUG && (os(iOS) || os(watchOS))
        return "\(HealthDataMode.currentRevision):\(developmentRevision)"
        #else
        return HealthDataMode.currentRevision
        #endif
    }

    #if DEBUG && (os(iOS) || os(watchOS))
    /// Replaces one day's measurements in this process. Derived averages remain repository calculations.
    func replaceDevelopmentMeasurements(_ day: HealthData, energyUnit: Settings.EnergyUnit) {

        if developmentSourceRevision != HealthDataMode.currentRevision { developmentDays.removeAll() }
        developmentSourceRevision = HealthDataMode.currentRevision
        let energy: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
        developmentDays[Calendar.current.startOfDay(for: day.date)] = [
            .activeEnergyBurned: HKQuantity(unit: energy, doubleValue: Double(day.burnedActive)),
            .basalEnergyBurned: HKQuantity(unit: energy, doubleValue: Double(day.burnedPassive)),
            .dietaryEnergyConsumed: HKQuantity(unit: energy, doubleValue: Double(day.consumed)),
            .dietaryProtein: HKQuantity(unit: .gram(), doubleValue: Double(day.protein)),
            .dietaryCarbohydrates: HKQuantity(unit: .gram(), doubleValue: Double(day.carbs)),
            .dietaryFatTotal: HKQuantity(unit: .gram(), doubleValue: Double(day.fats)),
            .stepCount: HKQuantity(unit: .count(), doubleValue: Double(day.steps))
        ]
        developmentRevision += 1
    }
    #endif

    /// Loads daily energy balances for a bounded streak count with fixed settings.
    func fetchStreakEnergy(
        endingOn date: Date,
        days: Int,
        source: Settings.DataSources,
        energyUnit: Settings.EnergyUnit,
        customActive: Int,
        customPassive: Int
    ) async throws -> [EnergyBalance] {

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
            async let activeSums: [Date: Double] = usesCustomEnergy ? [:] : try await measuredData.dailySums(
                .activeEnergyBurned,
                from: start,
                to: end,
                unit: unit
            )
            async let passiveSums: [Date: Double] = usesCustomEnergy ? [:] : try await measuredData.dailySums(
                .basalEnergyBurned,
                from: start,
                to: end,
                unit: unit
            )
            async let consumedSums = measuredData.dailySums(.dietaryEnergyConsumed, from: start, to: end, unit: unit)
            let sums = try await (activeSums, passiveSums, consumedSums)
            active = sums.0
            passive = sums.1
            consumed = sums.2
        }

        try Task.checkCancellation()
        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset - 1, to: end)!
            let burnedActive = usesCustomEnergy ? customActive : Int(active[day, default: 0].rounded())
            let burnedPassive = usesCustomEnergy ? customPassive : Int(passive[day, default: 0].rounded())
            let intake = Int(consumed[day, default: 0].rounded())
            return EnergyBalance(active: burnedActive, resting: burnedPassive, consumed: intake)
        }
    }

    /// Loads daily weight averages for the chart period ending on the given date.
    func fetchInitialAvgWeightData(for date: Date, weightUnit: Settings.WeightUnit) async throws -> [WeightChartData] {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        let dayStart = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Calendar.current.startOfDay(for: date)
        )!.lastMonday
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!

        let values = try await dataSource.weights(from: dayStart, to: dayEnd, unit: unit)
        return values.map { WeightChartData(date: $0.date, weightAvg: $0.weightAvg.map(WeightChartData.roundedWeight)) }
    }

    /// Returns the latest weight value and its sample date.
    func fetchLatestWeightData(for date: Date, weightUnit: Settings.WeightUnit) async throws -> (Double?, Date?) {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        let (weight, sampleDate) = try await dataSource.latestWeight(before: dayEnd, unit: unit)
        return (weight.map(WeightChartData.roundedWeight), sampleDate)
    }

    var earliestWeightSampleDate: Date? { dataSource.earliestWeightSampleDate }

    func weightChanges() -> AsyncStream<Void> { dataSource.weightChanges() }

    /// Sample mode never requests HealthKit authorization.
    func requestPermission() async -> Bool { await dataSource.requestPermission() }

    /// Returns the prior seven days' average for settings and legacy callers.
    func cumDataWeek(
        fetch dataType: HKQuantityTypeIdentifier,
        for date: Date,
        energyUnit: Settings.EnergyUnit? = nil
    ) async throws -> Int {

        let energyUnit = energyUnit ?? Settings.shared.energyUnit
        let measuredData = dataSource
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let unit: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
        return try await weeklyAverage(measuredData, dataType, from: start, to: end, unit: unit)
    }

}

extension HealthRepository {

    private func dailySum(
        _ source: any HealthDataSource,
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> Int {
        let sums = try await source.dailySums(type, from: start, to: end, unit: unit)
        return Int(sums[start, default: 0].rounded())
    }

    private func weeklyAverage(
        _ source: any HealthDataSource,
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> Int {
        let sums = try await source.dailySums(type, from: start, to: end, unit: unit)
        // The statistics collection can include the bucket at end. Exclude it.
        let total = sums.filter { $0.key >= start && $0.key < end }.values.reduce(0, +)
        return Int((total / 7).rounded())
    }

}

extension HealthRepository {

    var dataSource: any HealthDataSource {
        #if DEBUG && (os(iOS) || os(watchOS))
        if developmentSourceRevision == HealthDataMode.currentRevision, !developmentDays.isEmpty {
            return DevelopmentMeasurements(base: baseSource, days: developmentDays)
        }
        #endif
        return baseSource
    }

    private var baseSource: any HealthDataSource {
        if let injectedSource { return injectedSource }
        #if DEBUG && (os(iOS) || os(watchOS))
        if HealthDataMode.isSampleDataEnabled {
            return sampleSource(policy: HealthSnapshotPolicy(settings: .shared))
        }
        #endif
        return healthKit
    }

}

extension HealthRepository {

    private func snapshotSource(policy: HealthSnapshotPolicy, now: Date) -> any HealthDataSource {
        #if DEBUG && (os(iOS) || os(watchOS))
        if injectedSource == nil, HealthDataMode.isSampleDataEnabled,
           developmentSourceRevision != HealthDataMode.currentRevision || developmentDays.isEmpty {
            return sampleSource(policy: policy, now: now)
        }
        #endif
        return dataSource
    }

    #if DEBUG && (os(iOS) || os(watchOS))
    private func sampleSource(policy: HealthSnapshotPolicy, now: Date = .now) -> SampleHealthDataSource {
        let marketing = HealthDataMode.isMarketingDataEnabled ? MarketingHealthProfile(
            balanceGoal: Double(policy.balanceGoal) / (policy.energyUnit == .kJ ? 4.184 : 1),
            proteinGoal: policy.proteinGoal,
            carbsGoal: policy.carbsGoal,
            fatsGoal: policy.fatsGoal
        ) : nil
        return SampleHealthDataSource(now: now, marketing: marketing, profile: HealthDataMode.currentSampleProfile)
    }
    #endif

}

#if DEBUG && (os(iOS) || os(watchOS))
extension HealthRepository {

    private struct DevelopmentMeasurements: HealthDataSource {

        let base: any HealthDataSource
        let days: [Date: [HKQuantityTypeIdentifier: HKQuantity]]

        func dailySums(
            _ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit
        ) async throws -> [Date: Double] {
            replacing(try await base.dailySums(type, from: start, to: end, unit: unit), type, start, end, unit)
        }

        func energySums(
            _ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit
        ) async throws -> [Date: Double] {
            replacing(try await base.energySums(type, from: start, to: end, unit: unit), type, start, end, unit)
        }

        func energyIntervals(
            _ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit
        ) async throws -> [Date: Double] {

            let intervals = try await base.energyIntervals(type, from: start, to: end, unit: unit)
            guard let quantity = days[Calendar.current.startOfDay(for: start)]?[type], end > start else {
                return intervals
            }
            let value = quantity.doubleValue(for: unit)
            let total = intervals.values.reduce(0, +)
            return total > 0 ? intervals.mapValues { $0 * value / total } : [start: value]
        }

        func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] {
            try await base.weights(from: start, to: end, unit: unit)
        }

        func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) {
            try await base.latestWeight(before: end, unit: unit)
        }

        var earliestWeightSampleDate: Date? { base.earliestWeightSampleDate }
        func weightChanges() -> AsyncStream<Void> { base.weightChanges() }
        func requestPermission() async -> Bool { await base.requestPermission() }

        private func replacing(
            _ values: [Date: Double], _ type: HKQuantityTypeIdentifier,
            _ start: Date, _ end: Date, _ unit: HKUnit
        ) -> [Date: Double] {

            var result = values
            for (day, quantities) in days where day >= start && day < end {
                if let quantity = quantities[type] { result[day] = quantity.doubleValue(for: unit) }
            }
            return result
        }

    }

}
#endif

extension HealthRepository {

    static let shared = HealthRepository()

}
