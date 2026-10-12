import HealthKit
import Testing
@testable import Count_kcal

struct HealthLoadingTests {

    @Test func unresolvedEnergyWaitsForData() {
        #expect(CalorieDataState(energy: nil, balanceGoal: 500, isLoss: true) == .loading)
        #expect(CalorieDataState(energy: nil, balanceGoal: 500, isLoss: false) == .loading)
    }

    @Test func confirmedMissingEnergyIsIncomplete() {
        #expect(CalorieDataState(energy: 0, balanceGoal: 500, isLoss: true) == .incomplete)
        #expect(CalorieDataState(energy: 0, balanceGoal: 500, isLoss: false) == .incomplete)
    }

    @Test func validBudgetsResolveWithoutWaiting() {
        #expect(CalorieDataState(energy: 2500, balanceGoal: 500, isLoss: true) == .ready)
        #expect(CalorieDataState(energy: 2500, balanceGoal: 500, isLoss: false) == .ready)
        #expect(CalorieDataState(energy: 500, balanceGoal: 0, isLoss: true) == .ready)
    }

    @Test func invalidGoalsRemainActionableWhileLoading() {
        #expect(CalorieDataState(energy: nil, balanceGoal: -1, isLoss: true) == .incomplete)
        #expect(CalorieDataState(energy: 500, balanceGoal: 500, isLoss: true) == .incomplete)
    }

    @MainActor @Test func emptyDayIsLoadedOnlyAfterItsQueriesFinish() async {

        let source = SuspendedHealthSource()
        let day = HealthInterface(.empty(for: .now), repository: HealthRepository(source: source))
        #expect(!day.hasLoadedSnapshot)
        let load = Task { await day.updateMetrics(animated: false) }
        await source.waitUntilSuspended()
        #expect(!day.hasLoadedSnapshot)
        #expect(day.sample.lastDataSync == nil)

        await source.finish()
        await load.value
        #expect(day.hasLoadedSnapshot)
        #expect(day.sample.steps == 0)
    }

    @MainActor @Test func cancelledPageCallerStillCompletesItsSharedDayLoad() async {

        let source = SuspendedHealthSource()
        let day = HealthInterface(.empty(for: .now), repository: HealthRepository(source: source))
        let load = Task { await day.updateMetrics(animated: false) }
        await source.waitUntilSuspended()
        load.cancel()
        #expect(!day.hasLoadedSnapshot)

        await source.finish()
        await load.value
        #expect(day.hasLoadedSnapshot)
    }

    @MainActor @Test func streakDoesNotPublishAnInitialZeroAsACompletedCount() async {

        let source = SuspendedHealthSource(queryCount: 3)
        let streak = Streak(repository: HealthRepository(source: source))
        #expect(!streak.hasLoadedCount)
        let load = Task { await streak.updateStreaks() }
        await source.waitUntilSuspended()
        #expect(!streak.hasLoadedCount)

        await source.finish()
        await load.value
        #expect(streak.hasLoadedCount)
        #expect(streak.streaks == 0)
        streak.reset()
        #expect(!streak.hasLoadedCount)
    }

}

/// Holds the real daily-query path open without timers or HealthKit permissions.
private actor SuspendedHealthSource: HealthDataSource {

    private let queryCount: Int
    private var queries: [CheckedContinuation<[Date: Double], Never>] = []
    private var suspended: CheckedContinuation<Void, Never>?
    private var finished = false

    init(queryCount: Int = 8) { self.queryCount = queryCount }

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        guard !finished else { return [:] }
        return await withCheckedContinuation { continuation in
            queries.append(continuation)
            if queries.count == queryCount {
                suspended?.resume()
                suspended = nil
            }
        }
    }

    func waitUntilSuspended() async {
        guard queries.count < queryCount else { return }
        await withCheckedContinuation { suspended = $0 }
    }

    func finish() {

        finished = true
        for query in queries { query.resume(returning: [:]) }
        queries.removeAll()
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] { [] }
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }

}
