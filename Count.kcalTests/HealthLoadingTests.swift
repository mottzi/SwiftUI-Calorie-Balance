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

    @MainActor @Test func editedMeasurementsKeepSnapshotsCountAndMembershipTogether() async {

        let settings = Settings.shared
        let original = (settings.dataSource, settings.energyUnit, settings.weightGoal, settings.balanceGoal)
        let nutrients = (settings.carbsGoal, settings.fatsGoal, settings.proteinGoal)
        defer {
            settings.dataSource = original.0
            settings.energyUnit = original.1
            settings.weightGoal = original.2
            settings.balanceGoal = original.3
            settings.carbsGoal = nutrients.0
            settings.fatsGoal = nutrients.1
            settings.proteinGoal = nutrients.2
        }
        settings.dataSource = .apple
        settings.energyUnit = .kcal
        settings.weightGoal = .lose
        settings.balanceGoal = 200
        let source = SuspendedHealthSource()
        await source.finish()
        let repository = HealthRepository(source: source)
        let today = Calendar.current.startOfDay(for: .now)
        let dates = (0...3).map { Calendar.current.date(byAdding: .day, value: -$0, to: today)! }
        func replace(_ date: Date, consumed: Int) {
            var day = HealthData.empty(for: date)
            day.burnedActive = 500
            day.burnedPassive = 1500
            day.consumed = consumed
            repository.replaceDevelopmentMeasurements(day, energyUnit: .kcal)
        }
        for date in dates { replace(date, consumed: 1500) }
        let page = HealthInterface(.empty(for: dates[1]), repository: repository)
        let streak = Streak(repository: repository)
        await page.updateMetrics(animated: false)
        await streak.updateStreaks()
        #expect(page.sample.balanceNow == 500)
        #expect(streak.streaks == 3)
        for date in dates { #expect(streak.contains(date)) }
        await settings.updateShow(repository: repository)
        #expect(settings.calorieDataState == .ready)
        #expect(settings.showResting == 643)

        let revision = repository.revision
        replace(dates[1], consumed: 2078)
        #expect(repository.revision != revision)
        #expect(!streak.hasLoadedCount)
        #expect(!streak.contains(dates[1]))
        #expect(settings.calorieDataState == .loading)
        await settings.updateShow(repository: repository)
        #expect(settings.calorieDataState == .ready)
        await page.updateMetrics(animated: false)
        await streak.updateStreaks()
        #expect(page.sample.balanceNow == -78)
        #expect(streak.hasLoadedCount)
        #expect(streak.streaks == 0)
        for date in dates.dropFirst() { #expect(!streak.contains(date)) }
        #expect(streak.contains(today))

        replace(dates[1], consumed: 1500)
        replace(dates[2], consumed: 2078)
        await streak.updateStreaks()
        #expect(streak.streaks == 1)
        #expect(streak.contains(dates[1]))
        #expect(!streak.contains(dates[2]))
        #expect(!streak.contains(dates[3]))

        settings.weightGoal = .gain
        #expect(!streak.hasLoadedCount)
        for date in dates { replace(date, consumed: 2300) }
        await streak.updateStreaks()
        #expect(streak.streaks == 3)
        for date in dates { #expect(streak.contains(date)) }
        for intake in [2199, 0] {
            replace(dates[1], consumed: intake)
            await streak.updateStreaks()
            #expect(streak.streaks == 0)
            #expect(!streak.contains(dates[1]))
        }
        replace(dates[1], consumed: 2200)
        await streak.updateStreaks()
        #expect(streak.streaks == 3)

        settings.energyUnit = .kJ
        #expect(!streak.hasLoadedCount)
        await page.updateMetrics(animated: false)
        let history = await repository.fetchStreakEnergy(
            endingOn: dates[1], days: 1, source: .apple, energyUnit: .kJ, customActive: 0, customPassive: 0
        )
        #expect(page.sample.now == history.first)
        #expect(page.sample.burnedActive == 2092)
        #expect(page.sample.consumed == 9205)

        let beforeDemo = repository.revision
        page.randomizeDemoData()
        #expect(repository.revision == beforeDemo)
        let unchanged = await repository.fetchDailySnapshot(for: dates[1])
        #expect(unchanged.now == history.first)
    }

    @MainActor @Test func editsInvalidateInFlightSnapshotsAndRecounts() async {

        let source = SuspendedHealthSource(queryCount: 19)
        let repository = HealthRepository(source: source)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let page = HealthInterface(.empty(for: yesterday), repository: repository)
        let streak = Streak(repository: repository)
        let pageLoad = Task { await page.updateMetrics(animated: false) }
        let recount = Task { await streak.updateStreaks() }
        await source.waitUntilSuspended()
        var changed = HealthData.empty(for: yesterday)
        changed.consumed = 1915
        repository.replaceDevelopmentMeasurements(changed, energyUnit: .kcal)
        await source.finish()
        await pageLoad.value
        await recount.value
        #expect(!page.hasLoadedSnapshot)
        #expect(!streak.hasLoadedCount)
        await page.updateMetrics(animated: false)
        await streak.updateStreaks()
        #expect(page.hasLoadedSnapshot)
        #expect(streak.hasLoadedCount)
        #expect(page.sample.consumed > 0)
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
