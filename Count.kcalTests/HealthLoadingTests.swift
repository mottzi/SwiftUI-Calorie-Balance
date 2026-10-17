import HealthKit
import Testing
@testable import Count_kcal

@Suite(.serialized)
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

    @MainActor @Test func editedMeasurementsKeepSnapshotsCountAndMembershipTogether() async throws {

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
        for date in dates.dropFirst() { #expect(streak.contains(date)) }
        #expect(!streak.contains(today))
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
        #expect(!streak.contains(today))

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
        for date in dates.dropFirst() { #expect(streak.contains(date)) }
        #expect(!streak.contains(today))
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
        let history = try await repository.fetchStreakEnergy(
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

        let source = SuspendedHealthSource(queryCount: 11)
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

    @MainActor @Test func failedFoodReadIsUnavailableAndCanRecover() async {

        let source = FailableHealthSource()
        let repository = HealthRepository(source: source)
        let day = HealthInterface(.empty(for: .now), repository: repository)
        let streak = Streak(repository: repository)
        await day.updateMetrics(animated: false)
        #expect(day.hasLoadedSnapshot)
        await source.fail(.dietaryEnergyConsumed)
        await day.updateMetrics(animated: false, force: true)
        await streak.updateStreaks()
        #expect(day.sample.isUnavailable)
        #expect(!day.hasLoadedSnapshot)
        #expect(day.sample.lastDataSync == nil)
        #expect(!streak.hasLoadedCount)
        await source.fail(nil)
        await day.updateMetrics(animated: false)
        await streak.updateStreaks()
        #expect(day.hasLoadedSnapshot)
        #expect(!day.sample.isUnavailable)
        #expect(streak.hasLoadedCount)
    }

    @MainActor @Test func customSnapshotDoesNotRequireUnusedBurnMeasurements() async {

        let source = FailableHealthSource()
        await source.fail(.basalEnergyBurned)
        let repository = HealthRepository(source: source)
        var policy = HealthSnapshotPolicy()
        policy.usesCustomEnergy = true
        policy.customActive = 500
        policy.customPassive = 1500
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let data = await repository.fetchDailySnapshot(for: yesterday, policy: policy)
        #expect(!data.isUnavailable)
        #expect(data.now.burned == 2000)
        #expect(data.consumed == 1000)
    }

    @MainActor @Test func capturedSnapshotKeepsItsOriginalUnitsAndGoals() async {

        let settings = Settings.shared
        let unit = settings.energyUnit
        let goal = settings.balanceGoal
        let nutrients = (settings.carbsGoal, settings.fatsGoal, settings.proteinGoal)
        defer {
            settings.energyUnit = unit
            settings.balanceGoal = goal
            settings.carbsGoal = nutrients.0
            settings.fatsGoal = nutrients.1
            settings.proteinGoal = nutrients.2
        }
        settings.energyUnit = .kcal
        settings.balanceGoal = 200
        let policy = HealthSnapshotPolicy(settings: settings)
        settings.energyUnit = .kJ
        settings.balanceGoal = 2000
        let repository = HealthRepository(source: FailableHealthSource())
        let data = await repository.fetchDailySnapshot(for: .now, policy: policy)
        #expect(!data.isUnavailable)
        #expect(data.consumed == 1000)
        #expect(policy.energyUnit == .kcal)
        #expect(policy.balanceGoal == 200)
        #expect(policy != HealthSnapshotPolicy(settings: settings))
    }

    @MainActor @Test func lateEstimatesCannotReplaceANewerRefresh() async {

        let settings = Settings.shared
        let unit = settings.energyUnit
        let nutrients = (settings.carbsGoal, settings.fatsGoal, settings.proteinGoal)
        defer {
            settings.energyUnit = unit
            settings.carbsGoal = nutrients.0
            settings.fatsGoal = nutrients.1
            settings.proteinGoal = nutrients.2
        }
        settings.energyUnit = .kcal
        let source = OrderedEstimatesSource()
        let repository = HealthRepository(source: source)
        let older = Task { await settings.updateShow(repository: repository) }
        await source.waitForQueries(2)
        let newer = Task { await settings.updateShow(repository: repository) }
        await source.waitForQueries(4)
        await source.finish(batch: 1, active: 600, resting: 2000)
        await newer.value
        #expect(settings.showActive + settings.showResting == 2600)
        await source.finish(batch: 0, active: 100, resting: 1000)
        await older.value
        #expect(settings.showActive + settings.showResting == 2600)

        let earlier = Task { await settings.updateShow(repository: repository) }
        await source.waitForQueries(6)
        let failing = Task { await settings.updateShow(repository: repository) }
        await source.waitForQueries(8)
        await source.finish(batch: 3, active: 0, resting: 0, fails: true)
        await failing.value
        await source.finish(batch: 2, active: 100, resting: 1000)
        await earlier.value
        #expect(settings.showActive + settings.showResting == 2600)
    }

    @MainActor @Test func watchSettingsTransferIncludesStepsAndAcceptsOlderPayloads() throws {

        let settings = Settings.shared
        let original = settings.stepsGoal
        defer { settings.stepsGoal = original }
        settings.stepsGoal = 15000
        let outbound = WatchSettingsSnapshot(settings: settings, weightHistory: nil)
        let context = try #require(outbound.context)
        settings.stepsGoal = 10000
        let received = try #require(WatchSettingsSnapshot(context: context))
        received.apply(to: settings)
        #expect(settings.stepsGoal == 15000)

        var legacy = context
        legacy.removeValue(forKey: "stepsGoal")
        let old = try #require(WatchSettingsSnapshot(context: legacy))
        settings.stepsGoal = 12000
        old.apply(to: settings)
        #expect(settings.stepsGoal == 12000)
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

private actor FailableHealthSource: HealthDataSource {

    private var failedType: HKQuantityTypeIdentifier?

    func fail(_ type: HKQuantityTypeIdentifier?) { failedType = type }

    func dailySums(
        _ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit
    ) async throws -> [Date: Double] {

        if type == failedType { throw HKError(.errorHealthDataUnavailable) }
        let energy: Double
        switch type {
            case .activeEnergyBurned: energy = 500
            case .basalEnergyBurned: energy = 1500
            case .dietaryEnergyConsumed: energy = 1000
            default: return [:]
        }
        return [start: HKQuantity(unit: .kilocalorie(), doubleValue: energy).doubleValue(for: unit)]
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] { [] }
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }

}

private actor OrderedEstimatesSource: HealthDataSource {

    private var queries: [(HKQuantityTypeIdentifier, Date, CheckedContinuation<[Date: Double], Error>)] = []

    func dailySums(
        _ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit
    ) async throws -> [Date: Double] {
        try await withCheckedThrowingContinuation { queries.append((type, start, $0)) }
    }

    func waitForQueries(_ count: Int) async {
        while queries.count < count { await Task.yield() }
    }

    func finish(batch: Int, active: Double, resting: Double, fails: Bool = false) {

        for index in (batch * 2)..<(batch * 2 + 2) {
            let (type, date, continuation) = queries[index]
            if fails {
                continuation.resume(throwing: HKError(.errorHealthDataUnavailable))
            } else {
                continuation.resume(returning: [date: (type == .activeEnergyBurned ? active : resting) * 7])
            }
        }
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] { [] }
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }

}


@Suite(.serialized)
struct MarketingHealthTests {

    private let profile = MarketingHealthProfile(
        balanceGoal: 200, proteinGoal: 150, carbsGoal: 240, fatsGoal: 93
    )

    @Test(arguments: [200, 500]) func macrosReconcileWithIntakeAndDeficit(goal: Int) throws {
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        let budget = Double(2600 - goal)
        let carbsGoal = Int((budget * 0.4 / 4).rounded())
        let fatsGoal = Int((budget * 0.35 / 9).rounded())
        let proteinGoal = Int((budget * 0.25 / 4).rounded())
        let profile = MarketingHealthProfile(
            balanceGoal: Double(goal), proteinGoal: proteinGoal, carbsGoal: carbsGoal, fatsGoal: fatsGoal
        )
        for daysAgo in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
            let day = try #require(SampleHealthDay(date: date, now: now))
            let carbs = try #require(profile.quantity(.dietaryCarbohydrates, on: day)).doubleValue(for: .gram())
            let fats = try #require(profile.quantity(.dietaryFatTotal, on: day)).doubleValue(for: .gram())
            let protein = try #require(profile.quantity(.dietaryProtein, on: day)).doubleValue(for: .gram())
            let eaten = try #require(profile.quantity(.dietaryEnergyConsumed, on: day)).doubleValue(for: .kilocalorie())
            #expect(carbs * 4 + fats * 9 + protein * 4 == eaten)
            if daysAgo == 0 {
                for (value, goal) in [(carbs, carbsGoal), (fats, fatsGoal), (protein, proteinGoal)] {
                    #expect((0.6...1).contains(value / Double(goal)))
                }
            }
        }
    }

    @MainActor @Test func todayHasRoundedEnergyAndVisibleProjectionAtAnyHour() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for hour in [1, 8, 15, 23] {
            let now = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            let repository = HealthRepository(source: SampleHealthDataSource(now: now, marketing: profile))
            let data = await repository.fetchDailySnapshot(for: today, policy: HealthSnapshotPolicy(), now: now)
            #expect(data.balanceMidnight == 240)
            #expect(data.balanceNow > 0)
            #expect(data.midnight.burned == 2600)
            for value in [data.burnedActive, data.burnedPassive, data.burnedPassiveRemaining, data.consumed] {
                #expect(value > 0)
                #expect(value % 10 == 0)
            }
            #expect(data.midnight.ratio(of: data.burnedPassiveRemaining) > 0.05)
            for (value, goal) in [(data.protein, 150), (data.carbs, 240), (data.fats, 93)] {
                #expect((0.6...1).contains(Double(value) / Double(goal)))
            }
        }
    }

    @MainActor @Test func everyRollingWeekHasTwoDifferentSurpluses() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let now = today.addingTimeInterval(12 * 3600)
        let repository = HealthRepository(source: SampleHealthDataSource(now: now, marketing: profile))
        for offset in 0..<14 {
            let end = calendar.date(byAdding: .day, value: -offset, to: today)!
            let days = try await repository.fetchStreakEnergy(
                endingOn: end, days: 7, source: .apple, energyUnit: .kcal, customActive: 0, customPassive: 0
            )
            let surpluses = days.filter { $0.balance < 0 }.map(\.balance).sorted()
            #expect(surpluses == [-360, -140])
            #expect(days.filter { $0.balance > 0 }.count == 5)
        }
    }

    @Test func marketingLeavesWeightSamplesUnchangedAndConvertsEnergyUnits() async throws {
        let today = Calendar.current.startOfDay(for: .now)
        let now = today.addingTimeInterval(12 * 3600)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: today)!
        let normal = SampleHealthDataSource(now: now)
        let marketing = SampleHealthDataSource(now: now, marketing: profile)
        let normalWeights = await normal.weights(from: start, to: now, unit: .gramUnit(with: .kilo))
        let marketingWeights = await marketing.weights(from: start, to: now, unit: .gramUnit(with: .kilo))
        #expect(normalWeights.map(\.weightAvg) == marketingWeights.map(\.weightAvg))
        let kcal = try await marketing.dailySums(.dietaryEnergyConsumed, from: today, to: now, unit: .kilocalorie())
        let kJ = try await marketing.dailySums(.dietaryEnergyConsumed, from: today, to: now, unit: .jouleUnit(with: .kilo))
        #expect(abs(kJ[today]! - kcal[today]! * 4.184) < 0.001)
    }
}
