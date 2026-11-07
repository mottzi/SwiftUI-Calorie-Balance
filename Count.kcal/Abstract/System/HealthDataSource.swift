import HealthKit

/// Measured values only. Settings policy and calculations belong to HealthRepository.
protocol HealthDataSource: Sendable {

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double]
    func energySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double]
    func energyIntervals(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> [Date: Double]
    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData]
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?)
    var earliestWeightSampleDate: Date? { get }
    func weightChanges() -> AsyncStream<Void>
    func measurementChanges() -> AsyncStream<Void>
    func requestPermission() async -> Bool

}

extension HealthDataSource {

    /// Sources without time records do not supply a contour.
    func energyIntervals(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async throws -> [Date: Double] { [:] }

    func energySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double] {
        try Task.checkCancellation()
        return try await dailySums(type, from: start, to: end, unit: unit)
    }

    // Sample fixtures have no platform retention limit or external updates.
    var earliestWeightSampleDate: Date? { nil }
    func weightChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func measurementChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }

}
