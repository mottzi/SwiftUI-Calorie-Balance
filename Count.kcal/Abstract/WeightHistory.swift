import SwiftUI

@MainActor
@Observable
/// Weight history and values used by the weekly and monthly charts.
final class WeightHistory {

    var dailyAverages: [WeightChartData] = []

    var latestWeight: Double?
    var latestWeightDate: Date?
    private(set) var updatedAt: Date?
    private(set) var weightUnit: Settings.WeightUnit?
    private(set) var isLoading = false
    private(set) var refreshFailed = false
    private(set) var supplementUpdatedAt: Date?
    private(set) var unavailableDates: Set<Date> = []

    @ObservationIgnored private let repository: HealthRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0

    init(repository: HealthRepository? = nil, settings: Settings? = nil) {
        self.repository = repository ?? .shared
        self.settings = settings ?? .shared
    }

    /// Loads daily weight averages and the latest weight measurement.
    func fetchData(supplement: WeightHistorySnapshot? = nil) async {

        if let weightUnit, weightUnit != settings.weightUnit { reset() }

        requestID += 1
        let currentRequest = requestID
        let revision = repository.revision
        let date = Date.now
        let weightUnit = settings.weightUnit
        let earliest = repository.earliestWeightSampleDate
        let supplement = supplement.flatMap { $0.unit == weightUnit.rawValue ? $0 : nil }
        isLoading = true
        refreshFailed = false
        defer { if currentRequest == requestID { isLoading = false } }

        do {
            async let data = repository.fetchInitialAvgWeightData(for: date, weightUnit: weightUnit)
            async let latest = repository.fetchLatestWeightData(for: date, weightUnit: weightUnit)
            let (weights, latestSample) = try await (data, latest)
            guard !Task.isCancelled, currentRequest == requestID, repository.revision == revision,
                  settings.weightUnit == weightUnit else { return }

            var days = weights
            var unavailable: Set<Date> = []
            var usedSupplement = false
            if let earliest {
                let olderDays = Dictionary(
                    (supplement?.dailyAverages ?? []).map { ($0.date, $0) },
                    uniquingKeysWith: { _, latest in latest }
                )
                for index in days.indices where days[index].date < earliest {
                    if let older = olderDays[days[index].date] {
                        days[index] = older
                        usedSupplement = true
                    } else {
                        unavailable.insert(days[index].date)
                    }
                }
            }

            dailyAverages = days
            latestWeight = latestSample.0
            latestWeightDate = latestSample.1
            // A successful empty recent query must not restore a deleted recent phone sample.
            if latestWeight == nil, let earliest, let supplement,
               let olderDate = supplement.latestWeightDate, olderDate < earliest,
               olderDate <= date, let olderWeight = supplement.latestWeight {
                latestWeight = olderWeight
                latestWeightDate = olderDate
                usedSupplement = true
            }
            unavailableDates = unavailable
            supplementUpdatedAt = usedSupplement ? supplement?.updatedAt : nil
            updatedAt = date
            self.weightUnit = weightUnit
        } catch {
            guard !Task.isCancelled, currentRequest == requestID, repository.revision == revision,
                  settings.weightUnit == weightUnit else { return }
            // Preserve a previous successful read; a first failed read can use the cached phone result.
            if updatedAt == nil, let supplement { apply(supplement) }
            refreshFailed = true
        }
    }

}

extension WeightHistory {

    /// Clears displayed values and prevents an earlier refresh from repopulating them.
    func reset() {

        requestID += 1
        dailyAverages = []
        latestWeight = nil
        latestWeightDate = nil
        updatedAt = nil
        weightUnit = nil
        isLoading = false
        refreshFailed = false
        supplementUpdatedAt = nil
        unavailableDates = []
    }

    /// Restores the phone's daily averages and latest measurement in the matching unit.
    func apply(_ snapshot: WeightHistorySnapshot) {

        guard snapshot.unit == settings.weightUnit.rawValue else {
            reset()
            return
        }
        requestID += 1
        dailyAverages = snapshot.dailyAverages
        latestWeight = snapshot.latestWeight
        latestWeightDate = snapshot.latestWeightDate
        updatedAt = snapshot.updatedAt
        weightUnit = settings.weightUnit
        isLoading = false
        refreshFailed = false
        supplementUpdatedAt = nil
        unavailableDates = []
    }

    func randomizeWeightData(start: Double, end: Double) {
        requestID += 1
        assert(start > end, "Start weight must be greater than end weight")

        // Set latest weight to the target end weight (lowest)
        latestWeight = end
        latestWeightDate = .now.subtractDays(Int.random(in: 1...20))

        var updatedData = dailyAverages
        let numberOfEntries = updatedData.count

        // Iterate through the array from start to end
        // Index 0 should be oldest (highest weight)
        // Last index should be newest (lowest weight)
        for index in 0..<numberOfEntries {
            let setNil: Bool = Double.random(in: 0.0...1.0) < 0.25

            if setNil {
                updatedData[index].weightAvg = nil
            } else {
                // Calculate progress where:
                // index 0 = 0.0 (start/highest weight)
                // last index = 1.0 (end/lowest weight)
                let progress: Double = Double(index) / Double(numberOfEntries - 1)

                // Calculate the total weight difference
                let weightDifference: Double = start - end

                // Calculate base weight trending down from start to end
                let baseWeight: Double = start - (weightDifference * progress)

                // Add subtle variations
                let wiggleAmplitude: Double = weightDifference / 10.0
                let wiggle: Double = wiggleAmplitude * sin(progress * 4.0 * .pi)

                updatedData[index].weightAvg = baseWeight + wiggle
            }
        }

        // Publish the completed series once so chart marks do not see partial data.
        dailyAverages = updatedData
    }

}

extension WeightHistory {

    /// Only known platform restrictions count here; sparse measurements do not.
    func hasLimitedHistory(for page: WeightPage) -> Bool {
        dailyAverages.suffix(page == .weekly ? 7 : 30).contains { unavailableDates.contains($0.date) }
    }

    /// Compares the latest chart value with the average for the selected period.
    func trend(for page: WeightPage) -> ComparisonResult? {
        guard dataLoaded, let latest = lastWeightValue(page) else { return nil }
        let average = average(for: page)
        if latest < average { return .orderedAscending }
        if latest > average { return .orderedDescending }
        return .orderedSame
    }

    /// The selected period's mean of recorded daily averages.
    func average(for page: WeightPage) -> Double {
        page == .weekly ? weightAvg7 : weightAvg30
    }

    /// The existing phone chart's calendar bounds for the selected period.
    func chartDateRange(for page: WeightPage) -> ClosedRange<Date>? {
        guard dataLoaded else { return nil }
        let data = averages(for: page)
        guard let first = data.first, let last = data.last else { return nil }
        let end = page == .weekly ? last.date.tomorrow : last.date.nextSunday.tomorrow
        return first.date ... end
    }

    /// The last successful query result for phone-to-watch transfer.
    var snapshot: WeightHistorySnapshot? {
        guard let updatedAt, let weightUnit else { return nil }
        return WeightHistorySnapshot(
            dailyAverages: dailyAverages,
            latestWeight: latestWeight,
            latestWeightDate: latestWeightDate,
            unit: weightUnit.rawValue,
            updatedAt: updatedAt
        )
    }

    func getYRange(_ page: WeightPage) -> ClosedRange<Int> {
        getYBottomRange(page) ... getYTopRange(page)
    }

    func createYRangeArray(_ page: WeightPage) -> [Int] {
        var rangeArray: [Int] = []

        for num in getYBottomRange(page) ... getYTopRange(page) {
            rangeArray.append(num)
        }

        return rangeArray
    }

    func validData(_ page: WeightPage) -> [WeightChartData] {
        averages(for: page).filter { $0.weightAvg != nil }
    }

    func lastWeightValue(_ page: WeightPage) -> Double? {
        averages(for: page).last(where: { $0.weightAvg != nil })?.weightAvg
    }

    /// The average recorded weight over the final 30 days.
    var weightAvg30: Double {
        average(days: 30)
    }

    /// The average recorded weight over the final seven days.
    var weightAvg7: Double {
        average(days: 7)
    }

    func getYTopRange(_ page: WeightPage) -> Int {
        switch page {
            case .weekly:  Int(floor(maxWeightData(page)?.weightAvg ?? 0.0) + 1.0)
            case .monthly: Int(round(maxWeightData(page)?.weightAvg ?? 0.0) + 1.0)
        }
    }

    func getYBottomRange(_ page: WeightPage) -> Int {
        switch page {
            case .weekly:  Int(ceil(minWeightData(page)?.weightAvg ?? 0.0) - 1.0)
            case .monthly: Int(round(minWeightData(page)?.weightAvg ?? 0.0) - 1.0)
        }
    }

    func minWeightData(_ page: WeightPage) -> WeightChartData? {
        guard dataLoaded else { return nil }
        return averages(for: page).min(by: {
            $0.weightAvg ?? .greatestFiniteMagnitude < $1.weightAvg ?? .greatestFiniteMagnitude
        })
    }

    func maxWeightData(_ page: WeightPage) -> WeightChartData? {
        guard dataLoaded else { return nil }
        return averages(for: page).max(by: { $0.weightAvg ?? 0.0 < $1.weightAvg ?? 0.0 })
    }

    /// Calendar-day entries used by the selected chart, including missing days.
    func averages(for page: WeightPage) -> [WeightChartData] {
        page == .weekly ? weeklyAverages : dailyAverages
    }

    /// The final seven daily entries shown by the weekly chart.
    var weeklyAverages: [WeightChartData] {
        if !dataLoaded { return [] }
        return Array(dailyAverages.suffix(7))
    }

    /// Reports whether the monthly chart has enough daily entries.
    var dataLoaded: Bool {
        dailyAverages.count >= 30
    }

}

extension WeightHistory {

    private func average(days: Int) -> Double {
        guard dataLoaded else { return 0 }
        let values = dailyAverages.suffix(days).compactMap(\.weightAvg)
        guard !values.isEmpty else { return 0 }
        return (values.reduce(0, +) / Double(values.count) * 10).rounded() / 10
    }

}

enum WeightPage: Int {

    case weekly = 0
    case monthly = 1

}

/// One calendar day's weight average for charts.
struct WeightChartData: Identifiable, Codable, Equatable, Sendable {

    let date: Date
    var weightAvg: Double?

    init(date: Date, weightAvg: Double?) {
        self.date = Calendar.current.startOfDay(for: date)
        self.weightAvg = weightAvg
    }

    var id: Date { date }

}

/// Phone weight measurements and their unit at the last refresh.
struct WeightHistorySnapshot: Codable, Equatable, Sendable {

    let dailyAverages: [WeightChartData]
    let latestWeight: Double?
    let latestWeightDate: Date?
    let unit: String
    let updatedAt: Date

}
