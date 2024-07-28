import HealthKit

func asyncFetchData() async throws -> HealthData
{
//    //#if DEBUG
//        return HealthData.example(for: .now)
//    //#endif
    
    var data = HealthData.empty(for: .now)
    
    async let activeFetch = asyncCumDataToday(fetch: .activeEnergyBurned)
    async let passiveFetch = asyncCumDataToday(fetch: .basalEnergyBurned)
    async let consumedFetch = asyncCumDataToday(fetch: .dietaryEnergyConsumed)
    async let passiveAvgFetch = asyncCumDataWeek(fetch: .basalEnergyBurned)
    
    async let carbsFetch = asyncCumDataToday(fetch: .dietaryCarbohydrates)
    async let proteinFetch = asyncCumDataToday(fetch: .dietaryProtein)
    async let fatsFetch = asyncCumDataToday(fetch: .dietaryFatTotal)
    
    let (active, passive, passiveAvg, consumed, protein, carbs, fats) = try await (activeFetch, passiveFetch, passiveAvgFetch, consumedFetch, proteinFetch, carbsFetch, fatsFetch)

    if Settings.shared.dataSource == .custom
    {
        data.burnedActive = Int((Double(Settings.shared.customCalActive) * Date.getDayProgress).rounded())
        data.burnedPassive = Int((Double(Settings.shared.customCalPassive) * Date.getDayProgress).rounded())
        
        data.burnedActive7 = Settings.shared.customCalActive
        data.burnedPassive7 = Settings.shared.customCalPassive
    }
    else
    {
        data.burnedActive = active
        data.burnedPassive = passive
        data.burnedPassive7 = passiveAvg
    }

    data.consumed = consumed
    
    data.carbs = carbs
    data.protein = protein
    data.fats = fats

    return data
}

func asyncCumDataToday(fetch dataType: HKQuantityTypeIdentifier) async throws -> Int
{
    let dayStart = Calendar.current.startOfDay(for: .now)
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
        case .dietaryProtein:       unit = HKUnit.gram()
        case .dietaryFatTotal:      unit = HKUnit.gram()
        case .dietaryCarbohydrates: unit = HKUnit.gram()
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
    
    let cum = try await query.result(for: HKRepository.shared.store).statistics(for: .now)?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
    
    return Int(cum.rounded())
}

func asyncCumDataWeek(fetch dataType: HKQuantityTypeIdentifier) async throws -> Int
{
    var dayStart = Calendar.current.startOfDay(for: Date())
    dayStart = Calendar.current.date(byAdding: .day, value: -7, to: dayStart)!

    var dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
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

    let cum = try await query.result(for: HKRepository.shared.store).statistics(for: dayStart)?.sumQuantity()?.doubleValue(for: Settings.shared.energyUnit == .kJ ? .jouleUnit(with: .kilo) : .kilocalorie()) ?? 0.0
    
    return Int((cum / 7).rounded())
}
