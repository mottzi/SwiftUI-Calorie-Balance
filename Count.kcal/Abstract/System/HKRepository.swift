import HealthKit

/// HealthKit access for energy, nutrient, step, and weight samples.
final class HKRepository {

    public let store = HKHealthStore()
    public let dataTypesToRead = Set(
    [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
    ])

    private init() {}

    @MainActor
    /// Fetches one daily value with fixed settings and calendar bounds.
    func fetchDailySnapshot(for date: Date, settings: Settings = .shared, now: Date = .now) async -> HealthData {

        // capture the policy and query range before any HealthKit suspension
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: dayStart)!
        let source = settings.dataSource
        let energyUnit = settings.energyUnit
        let customActive = settings.customCalActive
        let customPassive = settings.customCalPassive
        let isToday = calendar.isDate(date, inSameDayAs: now)
        var snapshot = HealthData.empty(for: dayStart)
        snapshot.usesAppleActiveAtMidnight = source == .apple

        if HKHealthStore.isHealthDataAvailable(), !Task.isCancelled {
            let energy: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
            let grams = HKUnit.gram()
            let count = HKUnit.count()

            // run independent queries against the same captured day
            async let active = dailySum(.activeEnergyBurned, from: dayStart, to: dayEnd, unit: energy)
            async let passive = dailySum(.basalEnergyBurned, from: dayStart, to: dayEnd, unit: energy)
            async let passiveAverage = weeklyAverage(.basalEnergyBurned, from: weekStart, to: dayStart, unit: energy)
            async let consumed = dailySum(.dietaryEnergyConsumed, from: dayStart, to: dayEnd, unit: energy)
            async let protein = dailySum(.dietaryProtein, from: dayStart, to: dayEnd, unit: grams)
            async let carbs = dailySum(.dietaryCarbohydrates, from: dayStart, to: dayEnd, unit: grams)
            async let fats = dailySum(.dietaryFatTotal, from: dayStart, to: dayEnd, unit: grams)
            async let steps = dailySum(.stepCount, from: dayStart, to: dayEnd, unit: count)
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

        if source == .custom {
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

extension HKRepository {

    @MainActor
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
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let start = calendar.date(byAdding: .day, value: -days, to: end)!
        let unit: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()

        var active: [Date: Int] = [:]
        var passive: [Date: Int] = [:]
        var consumed: [Date: Int] = [:]
        if HKHealthStore.isHealthDataAvailable(), !Task.isCancelled {
            async let activeSums = dailySums(.activeEnergyBurned, from: start, to: end, unit: unit)
            async let passiveSums = dailySums(.basalEnergyBurned, from: start, to: end, unit: unit)
            async let consumedSums = dailySums(.dietaryEnergyConsumed, from: start, to: end, unit: unit)
            let sums = await (activeSums, passiveSums, consumedSums)
            active = sums.0
            passive = sums.1
            consumed = sums.2
        }

        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset - 1, to: end)!
            let burnedActive = source == .custom ? customActive : active[day, default: 0]
            let burnedPassive = source == .custom ? customPassive : passive[day, default: 0]
            let intake = consumed[day, default: 0]
            return EnergyBalance(active: burnedActive, resting: burnedPassive, consumed: intake)
        }
    }

    /// Loads daily weight averages for the chart period ending on the given date.
    func fetchInitialAvgWeightData(for date: Date, weightUnit: Settings.WeightUnit) async -> [WeightChartData] {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        if !HKHealthStore.isHealthDataAvailable() {
            print("isHealthDataAvailable false")
            return []
        }
        
        let dayStart = Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Calendar.current.startOfDay(for: date)
        )!.lastMonday
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!//.nextSunday.tomorrow
        
        let fetchPredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.bodyMass),
            predicate: HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd)
        )

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: fetchPredicate,
            options: .discreteAverage,
            anchorDate: dayStart,
            intervalComponents: DateComponents(day: 1)
        )
        
        var returnData: [WeightChartData] = []
        
        if let data = try? await query.result(for: store) {
            data.enumerateStatistics(from: dayStart, to: dayEnd) { statistics, pointer in
                if let avg = statistics.averageQuantity() {
                    returnData.append(
                        WeightChartData(
                            date: statistics.startDate,
                            weightAvg: round(avg.doubleValue(for: unit) * 10) / 10.0
                        )
                    )
                } else {
                    returnData.append(WeightChartData(date: statistics.startDate, weightAvg: nil))
                }
            }
        }
    
        return returnData
    }
    
    /// Returns the latest weight value and its sample date.
    func fetchLatestWeightData(for date: Date, weightUnit: Settings.WeightUnit) async -> (Double?, Date?) {
        let unit: HKUnit = weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
        if !HKHealthStore.isHealthDataAvailable() {
            print("isHealthDataAvailable false")
            return (nil, nil)
        }
        
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        
        let fetchPredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.bodyMass),
            predicate: HKQuery.predicateForSamples(withStart: nil, end: dayEnd)
        )
                
        let query = HKSampleQueryDescriptor(
            predicates: [fetchPredicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1)
        
        var v: Double?
        var d: Date?
        
        if let result = try? await query.result(for: store) {
            if result.count == 1 {
                v = round(result[0].quantity.doubleValue(for: unit) * 10) / 10.0
                d = result[0].startDate
            }
        }
        
        return (v, d)
    }
      
    /// Requests read access to the health data used by the app.
    func requestPermission() async -> Bool {
        if let _ = try? await store.requestAuthorization(toShare: Set(), read: dataTypesToRead) {
            return true
        }
        
        return false
    }
     
    @MainActor
    /// Returns the prior seven days' average for settings and legacy callers.
    func cumDataWeek(
        fetch dataType: HKQuantityTypeIdentifier,
        for date: Date,
        energyUnit: Settings.EnergyUnit = Settings.shared.energyUnit
    ) async -> Int {

        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let unit: HKUnit = energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()
        return await weeklyAverage(dataType, from: start, to: end, unit: unit)
    }

}

extension HKRepository {

    /// Reads daily quantity sums in one HealthKit query over a date range.
    private func dailySums(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async -> [Date: Int] {

        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(type),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await query.result(for: store) else { return [:] }

        var sums: [Date: Int] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let quantity = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            sums[statistics.startDate] = Int(quantity.rounded())
        }
        return sums
    }

    /// Reads one quantity sum between calendar boundaries.
    private func dailySum(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> Int {

        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(type),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let statistics = try? await query.result(for: store)
        let sum = statistics?.statistics(for: start)?.sumQuantity()?.doubleValue(for: unit) ?? 0
        return Int(sum.rounded())
    }

    /// Reads the average daily quantity over the prior seven days.
    private func weeklyAverage(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async -> Int {

        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(type),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 7)
        )
        let statistics = try? await query.result(for: store)
        let sum = statistics?.statistics(for: start)?.sumQuantity()?.doubleValue(for: unit) ?? 0
        return Int((sum / 7).rounded())
    }

}

extension HKRepository {

    static let shared = HKRepository()

}
