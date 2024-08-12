import HealthKit
import WidgetKit
import UserNotifications

final class HKRepository
{
    private init() {}
    
    static let shared = HKRepository()
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
    
    func fetchInitialAvgWeightData(for date: Date) async -> [WeightChartData]
    {
        if !HKHealthStore.isHealthDataAvailable()
        {
            print("isHealthDataAvailable false")
            return []
        }
        
        if await !requestPermission()
        {
            print("requestPermission false")
            return []
        }
        
        let dayStart = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: date))!.lastMonday
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
        
        if let data = try? await query.result(for: HKRepository.shared.store)
        {
            data.enumerateStatistics(from: dayStart, to: dayEnd)
            { statistics, pointer in
                if let avg = statistics.averageQuantity()
                {
                    let unit: HKUnit = Settings.shared.weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)

                    returnData.append(WeightChartData(date: statistics.startDate, weightAvg: round(avg.doubleValue(for: unit) * 10) / 10.0))
                }
                else
                {
                    returnData.append(WeightChartData(date: statistics.startDate, weightAvg: nil))
                }
            }
        }
    
        return returnData
    }
    
    func fetchLatestWeightData() async -> (Double?, Date?)
    {
        if !HKHealthStore.isHealthDataAvailable()
        {
            print("isHealthDataAvailable false")
            return (nil, nil)
        }
        
        if await !requestPermission()
        {
            print("requestPermission false")
            return (nil, nil)
        }
        
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: .now)!
        
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
        
        if let result = try? await query.result(for: HKRepository.shared.store)
        {
            if result.count == 1
            {
                let unit: HKUnit = Settings.shared.weightUnit == .lbs ? .pound() : .gramUnit(with: .kilo)
                
                v = round(result[0].quantity.doubleValue(for: unit) * 10) / 10.0
                d = result[0].startDate
            }
        }
        
        return (v, d)
    }
      
    func requestPermission() async -> Bool
    {        
        if let _ = try? await store.requestAuthorization(toShare: Set(), read: dataTypesToRead)
        {
            return true
        }
        
        return false
    }
     
    func cumDataToday(fetch dataType: HKQuantityTypeIdentifier, for date: Date) async -> Int
    {
        if !HKHealthStore.isHealthDataAvailable() { return 0 }

        if await !requestPermission() { return 0 }
        
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart)!
        
        let fetchPredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(dataType),
            predicate: HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd)
        )

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: fetchPredicate,
            options: .cumulativeSum,
            anchorDate: dayStart,
            intervalComponents: DateComponents(day: 1)
        )
        
        var unit: HKUnit
        
        switch dataType
        {
            case .dietaryProtein: unit = HKUnit.gram()
            case .dietaryFatTotal: unit = HKUnit.gram()
            case .dietaryCarbohydrates: unit = HKUnit.gram()
            case .stepCount: unit = HKUnit.count()
            default:
                if Settings.shared.energyUnit == .kJ
                {
                    unit = HKUnit.jouleUnit(with: .kilo)
                }
                else
                {
                    unit = HKUnit.kilocalorie()
                }
        }
        
        let cum = try? await query.result(for: HKRepository.shared.store).statistics(for: date)?.sumQuantity()?.doubleValue(for: unit) ?? 0
        
        return Int((cum ?? 0).rounded())
    }
    
    func cumDataWeek(fetch dataType: HKQuantityTypeIdentifier, for date: Date) async -> Int
    {
        if !HKHealthStore.isHealthDataAvailable()
        {
            print("isHealthDataAvailable false")
            return 0
        }

        if await !requestPermission()
        {
            print("requestPermission false")
            return 0
        }
        
        var dayStart = Calendar.current.startOfDay(for: date)
        dayStart = Calendar.current.date(byAdding: .day, value: -7, to: dayStart)!

        var dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        dayEnd = Calendar.current.date(byAdding: .day, value: -1, to: dayEnd)!
        
        let fetchPredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(dataType),
            predicate: HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd)
        )

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: fetchPredicate,
            options: .cumulativeSum,
            anchorDate: dayStart,
            intervalComponents: DateComponents(day: 7)
        )

        let cum = try? await query.result(for: HKRepository.shared.store).statistics(for: dayStart)?.sumQuantity()?.doubleValue(for: Settings.shared.energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()) ?? 0.0

        return Int(((cum ?? 0) / 7).rounded())
    }
}
