import HealthKit

/// The production adapter. It requests read access only and never saves samples.
final class HealthKitDataSource: HealthDataSource {

    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable(), !Task.isCancelled else { return [:] }
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
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            sums[statistics.startDate] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData] {
        guard HKHealthStore.isHealthDataAvailable(), !Task.isCancelled else { return [] }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.bodyMass),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .discreteAverage,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await query.result(for: store) else { return [] }
        var weights: [WeightChartData] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            weights.append(WeightChartData(
                date: statistics.startDate,
                weightAvg: statistics.averageQuantity()?.doubleValue(for: unit)
            ))
        }
        return weights
    }

    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?) {
        guard HKHealthStore.isHealthDataAvailable(), !Task.isCancelled else { return (nil, nil) }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.bodyMass),
            predicate: HKQuery.predicateForSamples(withStart: nil, end: end)
        )
        let query = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await query.result(for: store).first else { return (nil, nil) }
        return (sample.quantity.doubleValue(for: unit), sample.startDate)
    }

    func requestPermission() async -> Bool {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .basalEnergyBurned, .dietaryEnergyConsumed,
            .dietaryProtein, .dietaryFatTotal, .dietaryCarbohydrates, .bodyMass, .stepCount
        ]
        let types = Set(identifiers.map { HKQuantityType($0) as HKObjectType })
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return true
        } catch { return false }
    }

}
