import HealthKit
import OSLog

/// The production adapter. It requests read access only and never saves samples.
final class HealthKitDataSource: HealthDataSource {

    private let store: HKHealthStore
    private static let logger = Logger(subsystem: "com.count.kcal.app", category: "HealthKit")

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
        let collection = try await read(.bodyMass, from: start, to: end) {
            try await query.result(for: store)
        }
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
        let samples = try await read(.bodyMass, from: nil, to: end) {
            try await query.result(for: store)
        }
        guard let sample = samples.first else { return (nil, nil) }
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
        } catch {
            if !(error is CancellationError), !Task.isCancelled {
                let failure = error as NSError
                Self.logger.error("Authorization request failed: domain=\(failure.domain, privacy: .public) code=\(failure.code)")
            }
            return false
        }
    }

    /// Foreground invalidation only. Cancelling the consumer stops the observer.
    func measurementChanges() -> AsyncStream<Void> {
        guard HKHealthStore.isHealthDataAvailable() else { return AsyncStream { $0.finish() } }
        let identifiers: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned, .basalEnergyBurned, .dietaryEnergyConsumed,
            .dietaryProtein, .dietaryFatTotal, .dietaryCarbohydrates, .stepCount
        ]
        let descriptors = identifiers.map { HKQueryDescriptor(sampleType: HKQuantityType($0), predicate: nil) }
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let query = HKObserverQuery(queryDescriptors: descriptors) { _, _, _, error in
            if let error {
                let failure = error as NSError
                Self.logger.error("Measurement observer failed: domain=\(failure.domain, privacy: .public) code=\(failure.code)")
                return
            }
            continuation.yield(())
        }
        let store = store
        continuation.onTermination = { _ in store.stop(query) }
        store.execute(query)
        return stream
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
        let collection = try await read(type, from: start, to: end) {
            try await query.result(for: store)
        }
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            sums[statistics.startDate] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    /// Keep query failures diagnosable without logging sample values or error userInfo.
    private func read<Value>(
        _ type: HKQuantityTypeIdentifier,
        from start: Date?,
        to end: Date,
        operation: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch {
            if !(error is CancellationError), !Task.isCancelled {
                let failure = error as NSError
                let lowerBound = start?.ISO8601Format() ?? "unbounded"
                Self.logger.error("Read failed: type=\(type.rawValue, privacy: .public) start=\(lowerBound, privacy: .public) end=\(end.ISO8601Format(), privacy: .public) domain=\(failure.domain, privacy: .public) code=\(failure.code)")
            }
            throw error
        }
    }

}
