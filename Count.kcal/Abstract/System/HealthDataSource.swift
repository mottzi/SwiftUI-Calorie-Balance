import HealthKit

/// Measured values only. Settings policy and calculations belong to HealthRepository.
protocol HealthDataSource: Sendable {

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double]
    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData]
    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?)
    func requestPermission() async -> Bool

}
