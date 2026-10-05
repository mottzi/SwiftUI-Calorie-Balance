import Foundation

@main
struct WeightHistorySemantics {

    @MainActor
    static func main() async throws {

        let calendar = Calendar.current
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!
        let start = calendar.date(byAdding: .day, value: -34, to: end)!
        let settings = Settings()
        let source = HealthRepository()
        let phone = WeightHistory(repository: source, settings: settings)
        let watch = WeightHistory(repository: source, settings: settings)
        let weekly: [Double?] = [nil, 78, 79, nil, 80, 81, 82]
        source.weights = (0..<35).map { index in
            WeightChartData(
                date: calendar.date(byAdding: .day, value: index, to: start)!,
                weightAvg: index < 5 ? 1000 : index < 28 ? 80 : weekly[index - 28]
            )
        }
        source.latest = (77, end.addingTimeInterval(8 * 3600))
        await phone.fetchData()

        let snapshot = try roundTrip(phone.snapshot!)
        watch.apply(snapshot)
        checkParity(phone, watch)
        precondition(watch.weeklyAverages.count == 7)
        precondition(watch.validData(.weekly).count == 5)
        precondition(watch.weightAvg7 == 80 && watch.weightAvg30 == 80)
        precondition(watch.dailyAverages.count == 35)
        precondition(watch.lastWeightValue(.weekly) == 82 && watch.latestWeight == 77)
        precondition(watch.trend(for: .weekly) == .orderedDescending)
        precondition(watch.getYRange(.weekly) == 77...83)
        precondition(watch.getYRange(.monthly) == 77...1001)
        precondition(watch.chartDateRange(for: .weekly) == end.subtractDays(6)...end.tomorrow)
        precondition(watch.chartDateRange(for: .monthly) == start...end.addDays(8))

        settings.weightUnit = .lbs
        source.weights = source.weights.enumerated().map { index, day in
            let weekly: [Double?] = [nil, 170, 171, nil, 172, 173, 174]
            return WeightChartData(date: day.date, weightAvg: index < 28 ? 176.4 : weekly[index - 28])
        }
        source.latest = (169.8, source.latest.1)
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        checkParity(phone, watch)
        precondition(watch.snapshot?.unit == "lbs")
        precondition(watch.weightAvg7 == 172 && watch.weightAvg30 == 175.6)

        settings.weightUnit = .kg
        watch.apply(phone.snapshot!)
        precondition(watch.snapshot == nil && watch.latestWeight == nil && watch.dailyAverages.isEmpty)

        source.delay = true
        source.started = false
        let pending = Task { await phone.fetchData() }
        while !source.started { await Task.yield() }
        settings.weightUnit = .lbs
        await pending.value
        precondition(
            phone.snapshot == nil,
            "Changing units clears old values; an obsolete query must not repopulate them"
        )
        source.delay = false

        source.delay = true
        source.started = false
        let resetPending = Task { await phone.fetchData() }
        while !source.started { await Task.yield() }
        phone.reset()
        await resetPending.value
        precondition(phone.snapshot == nil && phone.dailyAverages.isEmpty)
        source.delay = false

        source.weights = source.weights.map { WeightChartData(date: $0.date, weightAvg: nil) }
        source.latest = (nil, nil)
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        checkParity(phone, watch)
        precondition(watch.validData(.monthly).isEmpty && watch.weightAvg30 == 0)
        precondition(watch.trend(for: .weekly) == nil && watch.latestWeight == nil)

        source.weights[source.weights.count - 4].weightAvg = 90
        source.latest = (88, end.subtractDays(40))
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        checkParity(phone, watch)
        precondition(watch.weightAvg7 == 90 && watch.weightAvg30 == 90)
        precondition(watch.trend(for: .weekly) == .orderedSame)
        precondition(watch.latestWeightDate == end.subtractDays(40))

        source.weights[source.weights.count - 2].weightAvg = 80
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        checkParity(phone, watch)
        precondition(watch.weightAvg7 == 85 && watch.trend(for: .weekly) == .orderedAscending)

        source.weights = []
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        precondition(!watch.dataLoaded && watch.chartDateRange(for: .weekly) == nil)
        precondition(watch.latestWeight == 88)
        watch.reset()
        precondition(watch.snapshot == nil && watch.latestWeight == nil && watch.updatedAt == nil)

        source.weights = [WeightChartData(date: end, weightAvg: 80)]
        await phone.fetchData()
        watch.apply(try roundTrip(phone.snapshot!))
        precondition(!watch.dataLoaded && watch.average(for: .monthly) == 0)
        precondition(watch.chartDateRange(for: .monthly) == nil)
        await checkLocalDelivery(calendar: calendar, end: end, start: start)
        print(
            """
            PASS: shared phone/watch weight means, dates, gaps, trends, units, latest sample, \
            empty state, reset and snapshot round trip
            """
        )
    }

}

extension WeightHistorySemantics {

    static func roundTrip(_ snapshot: WeightHistorySnapshot) throws -> WeightHistorySnapshot {

        let data = try PropertyListEncoder().encode(snapshot)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        let context: [String: Any] = ["weightHistory": value, "weightUnit": snapshot.unit]
        let encoded = try PropertyListSerialization.data(fromPropertyList: context, format: .binary, options: 0)
        let decoded = try PropertyListSerialization.propertyList(from: encoded, format: nil) as! [String: Any]
        let weights = try PropertyListSerialization.data(
            fromPropertyList: decoded["weightHistory"]!,
            format: .binary,
            options: 0
        )
        let restored = try PropertyListDecoder().decode(WeightHistorySnapshot.self, from: weights)
        precondition(restored == snapshot)
        return restored
    }

    @MainActor
    static func checkParity(_ phone: WeightHistory, _ watch: WeightHistory) {

        precondition(phone.snapshot == watch.snapshot)
        for period in [WeightPage.weekly, .monthly] {
            precondition(phone.averages(for: period) == watch.averages(for: period))
            precondition(phone.validData(period) == watch.validData(period))
            precondition(phone.average(for: period) == watch.average(for: period))
            precondition(phone.trend(for: period) == watch.trend(for: period))
            precondition(phone.getYRange(period) == watch.getYRange(period))
            precondition(phone.chartDateRange(for: period) == watch.chartDateRange(for: period))
        }
    }

    @MainActor
    static func checkLocalDelivery(calendar: Calendar, end: Date, start: Date) async {

        let settings = Settings()
        let source = HealthRepository()
        let phone = WeightHistory(repository: source, settings: settings)
        let watch = WeightHistory(repository: source, settings: settings)
        source.weights = (0..<35).map { index in
            WeightChartData(date: start.addDays(index), weightAvg: 80)
        }
        source.latest = (80, end)
        await phone.fetchData()
        let supplement = phone.snapshot!

        // With identical local inputs, direct reads have the same phone semantics in either unit.
        await watch.fetchData()
        checkParityValues(phone, watch)
        for unit in [Settings.WeightUnit.lbs, .kg] {
            settings.weightUnit = unit
            let value = unit == .kg ? 80.0 : 176.4
            source.weights = source.weights.map { WeightChartData(date: $0.date, weightAvg: value) }
            source.latest = (value, end)
            await phone.fetchData()
            await watch.fetchData()
            checkParityValues(phone, watch)
            precondition(watch.snapshot?.unit == unit.rawValue)
        }

        // Only days before the known local boundary can come from the phone.
        source.earliestWeightSampleDate = end.subtractDays(6)
        source.weights = source.weights.map {
            WeightChartData(date: $0.date, weightAvg: $0.date < end.subtractDays(6) ? nil : 79)
        }
        source.latest = (78.5, end)
        await watch.fetchData(supplement: supplement)
        precondition(watch.latestWeight == 78.5 && watch.weightAvg7 == 79)
        precondition(watch.weightAvg30 == 79.8)
        precondition(watch.dailyAverages.prefix(28).allSatisfy { $0.weightAvg == 80 })
        precondition(!watch.hasLimitedHistory(for: .monthly) && watch.supplementUpdatedAt == supplement.updatedAt)

        // A phone snapshot is optional. Incomplete older history is marked rather than inferred as zero.
        await watch.fetchData()
        precondition(watch.weightAvg7 == 79 && watch.weightAvg30 == 79)
        precondition(!watch.hasLimitedHistory(for: .weekly) && watch.hasLimitedHistory(for: .monthly))
        precondition(watch.supplementUpdatedAt == nil)

        // Successful empty recent reads must not resurrect the phone's recent measurement.
        source.weights = source.weights.map { WeightChartData(date: $0.date, weightAvg: nil) }
        source.latest = (nil, nil)
        await watch.fetchData(supplement: supplement)
        precondition(watch.latestWeight == nil && watch.validData(.weekly).isEmpty)
        precondition(watch.weightAvg30 == 80)

        // A latest measurement outside the watch boundary can still be supplied by the phone.
        let older = WeightHistorySnapshot(
            dailyAverages: supplement.dailyAverages,
            latestWeight: 81,
            latestWeightDate: end.subtractDays(40),
            unit: "kg",
            updatedAt: supplement.updatedAt
        )
        await watch.fetchData(supplement: older)
        precondition(watch.latestWeight == 81 && watch.latestWeightDate == end.subtractDays(40))

        // Sources without a platform boundary do not merge conflicting phone history.
        source.earliestWeightSampleDate = nil
        source.weights = source.weights.map { WeightChartData(date: $0.date, weightAvg: 75) }
        source.latest = (74, end)
        await watch.fetchData(supplement: supplement)
        precondition(watch.weightAvg30 == 75 && watch.latestWeight == 74 && watch.supplementUpdatedAt == nil)

        // Error and empty success are different. A failed refresh preserves the previous result.
        let previous = watch.snapshot
        source.fail = true
        await watch.fetchData(supplement: supplement)
        precondition(watch.snapshot == previous && watch.refreshFailed && !watch.isLoading)
        watch.reset()
        await watch.fetchData(supplement: supplement)
        precondition(watch.snapshot == supplement && watch.refreshFailed && !watch.isLoading)
        watch.reset()
        await watch.fetchData()
        precondition(watch.snapshot == nil && watch.refreshFailed && !watch.isLoading)
        source.fail = false

        // Wrong-unit supplements cannot enter a locally restricted series.
        settings.weightUnit = .lbs
        source.earliestWeightSampleDate = end.subtractDays(6)
        source.weights = source.weights.map {
            WeightChartData(date: $0.date, weightAvg: $0.date < end.subtractDays(6) ? nil : 176)
        }
        source.latest = (176, end)
        await watch.fetchData(supplement: supplement)
        precondition(
            watch.weightAvg30 == 176 && watch.supplementUpdatedAt == nil && watch.hasLimitedHistory(for: .monthly)
        )
        print(
            """
            PASS: independent local reads in kg/lbs, older-history supplement, local precedence, deletion, \
            limited history and refresh failures
            """
        )
    }

    @MainActor
    static func checkParityValues(_ phone: WeightHistory, _ watch: WeightHistory) {

        precondition(phone.dailyAverages == watch.dailyAverages)
        precondition(phone.latestWeight == watch.latestWeight && phone.latestWeightDate == watch.latestWeightDate)
        for period in [WeightPage.weekly, .monthly] {
            precondition(phone.average(for: period) == watch.average(for: period))
            precondition(phone.trend(for: period) == watch.trend(for: period))
            precondition(phone.chartDateRange(for: period) == watch.chartDateRange(for: period))
            precondition(phone.getYRange(period) == watch.getYRange(period))
        }
    }

}

// test fixtures replace only the model's query and settings dependencies
@MainActor
final class Settings {

    var weightUnit: WeightUnit = .kg

    enum WeightUnit: String { case kg, lbs }

    static let shared = Settings()

}

@MainActor
final class HealthRepository {
    var revision = "fixture"
    var weights: [WeightChartData] = []
    var latest: (Double?, Date?) = (nil, nil)
    var earliestWeightSampleDate: Date?
    var fail = false
    var delay = false
    var started = false

    func fetchInitialAvgWeightData(for date: Date, weightUnit: Settings.WeightUnit) async throws -> [WeightChartData] {

        started = true
        if delay { try? await Task.sleep(for: .milliseconds(30)) }
        if fail { throw Failure.query }
        return weights
    }

    func fetchLatestWeightData(for date: Date, weightUnit: Settings.WeightUnit) async throws -> (Double?, Date?) {
        if delay { try? await Task.sleep(for: .milliseconds(30)) }
        if fail { throw Failure.query }
        return latest
    }

    enum Failure: Error { case query }

    static let shared = HealthRepository()

}
