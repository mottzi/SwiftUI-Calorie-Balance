import HealthKit

/// The production adapter. It requests read access only and never saves samples.
final class HealthKitDataSource: HealthDataSource {

    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) { self.store = store }

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double] {
        try await energySums(type, from: start, to: end, unit: unit)
    }

    func energySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double] {
        try await sums(type, from: start, to: end, unit: unit, interval: DateComponents(day: 1))
    }

    /// Returns measured energy in fifteen-minute intervals.
    func energyIntervals(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> [Date: Double] {
        try await sums(type, from: start, to: end, unit: unit, interval: DateComponents(minute: 15))
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] {
        try Task.checkCancellation()
        guard HKHealthStore.isHealthDataAvailable() else { throw HKError(.errorHealthDataUnavailable) }
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
        let collection = try await query.result(for: store)
        var weights: [WeightChartData] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            weights.append(WeightChartData(
                date: statistics.startDate,
                weightAvg: statistics.averageQuantity()?.doubleValue(for: unit)
            ))
        }
        return weights
    }

    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) {
        try Task.checkCancellation()
        guard HKHealthStore.isHealthDataAvailable() else { throw HKError(.errorHealthDataUnavailable) }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.bodyMass),
            predicate: HKQuery.predicateForSamples(withStart: nil, end: end)
        )
        let query = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try await query.result(for: store).first else { return (nil, nil) }
        return (sample.quantity.doubleValue(for: unit), sample.startDate)
    }

    var earliestWeightSampleDate: Date? {
        #if os(watchOS)
        store.earliestPermittedSampleDate()
        #else
        nil
        #endif
    }

    /// Observe only while a foreground consumer is listening; no background delivery needed.
    func weightChanges() -> AsyncStream<Void> {

        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let query = HKObserverQuery(sampleType: HKQuantityType(.bodyMass), predicate: nil) { _, completion, _ in
            continuation.yield(())
            completion()
        }
        let store = store
        continuation.onTermination = { _ in store.stop(query) }
        store.execute(query)
        return stream
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

extension HealthKitDataSource {

    private func sums(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit,
        interval: DateComponents
    ) async throws -> [Date: Double] {

        try Task.checkCancellation()
        guard HKHealthStore.isHealthDataAvailable() else { throw HKError(.errorHealthDataUnavailable) }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(type),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )
        let collection = try await query.result(for: store)
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            sums[statistics.startDate] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

}
