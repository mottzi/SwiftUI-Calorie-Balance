#if DEBUG
import HealthKit
import Testing
@testable import Count_kcal

@MainActor
@Suite(.serialized)
struct HealthDataTests {
    private func withSamples(_ test: () async throws -> Void) async rethrows {
        let mode = HealthDataMode.shared
        let settings = Settings.shared
        let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!
        let storedMode = defaults.dictionary(forKey: "debugHealthDataMode")
        let enabled = mode.usesSampleData
        let source = settings.dataSource
        let unit = settings.energyUnit
        let active = settings.customCalActive
        let passive = settings.customCalPassive
        defer {
            mode.usesSampleData = enabled
            if let storedMode { defaults.set(storedMode, forKey: "debugHealthDataMode") }
            else { defaults.removeObject(forKey: "debugHealthDataMode") }
            settings.dataSource = source
            settings.energyUnit = unit
            settings.customCalActive = active
            settings.customCalPassive = passive
        }
        mode.usesSampleData = true
        settings.dataSource = .apple
        settings.energyUnit = .kcal
        try await test()
    }

    @Test func sampleModePersistsWithoutChangingGoals() async {
        await withSamples {
            let settings = Settings.shared
            let goal = settings.balanceGoal
            let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!
            #expect(defaults.dictionary(forKey: "debugHealthDataMode")?["enabled"] as? Bool == true)
            #expect(await HealthRepository.shared.requestPermission())
            #expect(settings.balanceGoal == goal)
            let first = HealthDataMode.currentRevision
            HealthDataMode.shared.usesSampleData = false
            HealthDataMode.shared.usesSampleData = true
            #expect(HealthDataMode.currentRevision != first)
        }
    }

    @Test func widgetRequestsReadSharedModeChanges() async {
        await withSamples {
            let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!
            // Model another process changing shared defaults after the singleton was created.
            defaults.set(["enabled": false, "revision": "external-mode-change"], forKey: "debugHealthDataMode")
            #expect(HealthDataMode.shared.usesSampleData)
            #expect(!HealthDataMode.isSampleDataEnabled)
            #expect(HealthRepository.shared.revision == "external-mode-change")
        }
    }

    @Test func historicalSnapshotsAndStreakInputsAgree() async {
        await withSamples {
            let date = Calendar.current.date(byAdding: .day, value: -180, to: .now)!
            let daily = await HealthRepository.shared.fetchDailySnapshot(for: date)
            let energy = await HealthRepository.shared.fetchStreakEnergy(
                endingOn: date, days: 1, source: .apple, energyUnit: .kcal, customActive: 0, customPassive: 0
            )
            #expect(daily.consumed > 0)
            #expect(daily.protein > 0)
            #expect(daily.steps > 0)
            #expect(energy == [daily.now])
            let future = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            #expect(await HealthRepository.shared.fetchDailySnapshot(for: future).consumed == 0)
        }
    }

    @Test func energyAndWeightUnitsConvertMeasurements() async {
        await withSamples {
            let date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            let kcal = await HealthRepository.shared.fetchDailySnapshot(for: date)
            Settings.shared.energyUnit = .kJ
            let kJ = await HealthRepository.shared.fetchDailySnapshot(for: date)
            #expect(abs(Double(kJ.consumed) - Double(kcal.consumed) * 4.184) <= 3)
            #expect(kJ.protein == kcal.protein)
            let (kg, _) = await HealthRepository.shared.fetchLatestWeightData(for: date, weightUnit: .kg)
            let (lbs, _) = await HealthRepository.shared.fetchLatestWeightData(for: date, weightUnit: .lbs)
            #expect(abs((lbs ?? 0) - (kg ?? 0) * 2.20462262) < 0.2)
            let weights = await HealthRepository.shared.fetchInitialAvgWeightData(for: .now, weightUnit: .kg)
            #expect(weights.count >= 30)
            #expect(weights.allSatisfy { $0.weightAvg != nil })
        }
    }

    @Test func customEnergyUsesSharedPolicy() async {
        await withSamples {
            HealthDataMode.shared.usesSampleData = false
            let settings = Settings.shared
            settings.dataSource = .custom
            settings.customCalActive = 400
            settings.customCalPassive = 1600
            let date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            let repository = HealthRepository(source: SampleHealthDataSource())
            let data = await repository.fetchDailySnapshot(for: date)
            #expect(data.burnedActive == 400)
            #expect(data.burnedPassive == 1600)
            #expect(!data.usesMeasuredActiveAtMidnight)
            #expect(data.consumed > 0)
        }
    }

    @Test func sampleModeOverridesCustomEnergyWithoutChangingPreferences() async {
        await withSamples {
            let settings = Settings.shared
            let date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            let expected = await HealthRepository.shared.fetchDailySnapshot(for: date)
            settings.dataSource = .custom
            settings.customCalActive = 400
            settings.customCalPassive = 1600
            let sampled = await HealthRepository.shared.fetchDailySnapshot(for: date)
            #expect(sampled.now == expected.now)
            #expect(sampled.usesMeasuredActiveAtMidnight)
            let streak = await HealthRepository.shared.fetchStreakEnergy(
                endingOn: date, days: 1, source: .custom, energyUnit: .kcal,
                customActive: 400, customPassive: 1600
            )
            #expect(streak == [expected.now])
            #expect(!settings.usesCustomEnergy)
            #expect(settings.dataSource == .custom)
            #expect(settings.customCalActive == 400)
            #expect(settings.customCalPassive == 1600)
            HealthDataMode.shared.usesSampleData = false
            #expect(settings.usesCustomEnergy)
        }
    }

    @Test func cancelledConcurrentEstimateRefreshDoesNotDiscardValidResults() async {
        await withSamples {
            let settings = Settings.shared
            let previousActive = settings.showActive
            let previousResting = settings.showResting
            defer {
                settings.showActive = previousActive
                settings.showResting = previousResting
            }
            settings.showActive = 0
            settings.showResting = 0
            let source = DelayedSource()
            let repository = HealthRepository(source: source)
            let first = Task { await settings.updateShow(repository: repository) }
            while await source.queriesStarted < 2 { await Task.yield() }
            let cancelled = Task { await settings.updateShow(repository: repository) }
            while await source.queriesStarted < 4 { await Task.yield() }
            cancelled.cancel()
            await cancelled.value
            await first.value
            #expect(settings.showActive == 700)
            #expect(settings.showResting == 700)
        }
    }

    @Test func weeklyAverageExcludesEndBucketAndIncludesMissingDays() async {
        await withSamples {
            let repository = HealthRepository(source: EndBucketSource())
            let average = await repository.cumDataWeek(fetch: .basalEnergyBurned, for: .now)
            // One recorded day of 700, six missing days, plus an excluded end bucket.
            #expect(average == 100)
        }
    }

    @Test func modeSwitchRejectsPendingSnapshot() async {
        await withSamples {
            let source = DelayedSource()
            let repository = HealthRepository(source: source)
            let model = HealthInterface(.empty(for: .now), repository: repository)
            let refresh = Task { await model.updateMetrics(animated: false) }
            // Wait until the old-mode request is in flight, then toggle twice.
            while await !source.started { await Task.yield() }
            HealthDataMode.shared.usesSampleData = false
            HealthDataMode.shared.usesSampleData = true
            await refresh.value
            #expect(model.sample.lastDataSync == nil)
            await model.updateMetrics(animated: false)
            #expect(model.sample.consumed == 700)
        }
    }

    @Test func resetRejectsPendingWeightRefresh() async {
        await withSamples {
            let source = DelayedSource()
            let weights = WeightHistory(repository: HealthRepository(source: source))
            let refresh = Task { await weights.fetchData() }
            while await !source.started { await Task.yield() }
            weights.reset()
            await refresh.value
            #expect(weights.dailyAverages.isEmpty)
            #expect(weights.latestWeight == nil)
            #expect(weights.latestWeightDate == nil)
            await weights.fetchData()
            #expect(weights.latestWeight == 80)
        }
    }

    @Test func resetRejectsPendingStreakRecount() async {
        await withSamples {
            let settings = Settings.shared
            let goal = settings.balanceGoal
            let weightGoal = settings.weightGoal
            defer {
                settings.balanceGoal = goal
                settings.weightGoal = weightGoal
            }
            settings.balanceGoal = 0
            settings.weightGoal = .lose
            let source = DelayedSource()
            let streak = Streak(repository: HealthRepository(source: source))
            streak.showStreaksView = false
            let refresh = Task { await streak.updateStreaks() }
            while await !source.started { await Task.yield() }
            streak.reset()
            await refresh.value
            #expect(streak.streaks == 0)
            #expect(!streak.showStreaksView)
            await streak.updateStreaks()
            #expect(streak.streaks > 0)
        }
    }

    @Test func sampleDaysRespectDaylightSavingAndHistoryBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let sample = SampleHealthDay(date: day, now: noon, calendar: calendar)!
        #expect(abs(sample.energyFraction - 11.0 / 23.0) < 0.0001)
        let oldest = calendar.date(byAdding: .day, value: -199, to: day)!
        let outside = calendar.date(byAdding: .day, value: -200, to: day)!
        #expect(SampleHealthDay(date: oldest, now: noon, calendar: calendar) != nil)
        #expect(SampleHealthDay(date: outside, now: noon, calendar: calendar) == nil)
    }
}

private struct EndBucketSource: HealthDataSource {
    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        [start: 700, end: 9999]
    }
    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData] { [] }
    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }
}

private actor DelayedSource: HealthDataSource {
    private(set) var started = false
    private(set) var queriesStarted = 0
    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        started = true
        queriesStarted += 1
        try? await Task.sleep(for: .milliseconds(50))
        var sums: [Date: Double] = [:]
        var day = start
        while day < end {
            sums[day] = 700
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        return sums
    }
    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData] {
        started = true
        try? await Task.sleep(for: .milliseconds(50))
        return [WeightChartData(date: start, weightAvg: 80)]
    }
    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?) {
        started = true
        try? await Task.sleep(for: .milliseconds(50))
        return (80, end)
    }
    func requestPermission() async -> Bool { true }
}

#endif
