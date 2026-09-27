import SwiftUI

@MainActor
@Observable
/// Weight history and values used by the weekly and monthly charts.
final class WeightDataViewModel {

    var WeightData: [WeightChartData] = []
    
    var weightLatest: Double?
    var weightLatestDate: Date?

    @ObservationIgnored private let hk: HKRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0

    init(repository: HKRepository = .shared, settings: Settings = .shared) {
        hk = repository
        self.settings = settings
    }

    /// Loads daily weight averages and the latest weight sample from HealthKit.
    func fetchData() async {

        requestID += 1
        let currentRequest = requestID
        let date = Date.now
        let weightUnit = settings.weightUnit
        async let data = hk.fetchInitialAvgWeightData(for: date, weightUnit: weightUnit)
        async let latest = hk.fetchLatestWeightData(for: date, weightUnit: weightUnit)
        let (weights, latestSample) = await (data, latest)
        // publish both query results only if this refresh is still current
        guard !Task.isCancelled, currentRequest == requestID else { return }

        WeightData = weights
        weightLatest = latestSample.0
        weightLatestDate = latestSample.1
    }

}

extension WeightDataViewModel {

    /// Reports whether the monthly chart has enough daily entries.
    var dataLoaded: Bool {
        WeightData.count >= 30
    }
    
    /// The final seven daily entries shown by the weekly chart.
    var WeeklyWeightData: [WeightChartData] {
        if !dataLoaded { return [] }
        return Array(WeightData.suffix(7))
    }

    /// The average recorded weight over the final 30 days.
    var weightAvg30: Double {
        average(days: 30)
    }
    
    /// The average recorded weight over the final seven days.
    var weightAvg7: Double {
        average(days: 7)
    }

    func validData(_ page: WeightPage) -> [WeightChartData] {
        if page == .weekly {
            return WeeklyWeightData.filter({ $0.weightAvg != nil })
        } else {
            return WeightData.filter({ $0.weightAvg != nil })
        }
    }

    /// Compares the latest chart value with the average for the selected period.
    func trend(for page: WeightPage) -> ComparisonResult? {
        guard dataLoaded, let latest = lastWeightValue(page) else { return nil }
        let average = page == .weekly ? weightAvg7 : weightAvg30
        if latest < average { return .orderedAscending }
        if latest > average { return .orderedDescending }
        return .orderedSame
    }
    
    func randomizeWeightData(start: Double, end: Double) {
        requestID += 1
        assert(start > end, "Start weight must be greater than end weight")
        
        // Set latest weight to the target end weight (lowest)
        weightLatest = end
        weightLatestDate = .now.subtractDays(Int.random(in: 1...20))
        
        var updatedData = WeightData
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
        WeightData = updatedData
    }
    
    func lastWeightValue(_ page: WeightPage) -> Double? {
        if page == .weekly {
            if let lastValidElement = WeeklyWeightData.last(where: { $0.weightAvg != nil })
            { return lastValidElement.weightAvg }
        } else {
            if let lastValidElement = WeightData.last(where: { $0.weightAvg != nil })
            { return lastValidElement.weightAvg }
        }
        
        return nil
    }
    
    func minWeightData(_ page: WeightPage) -> WeightChartData? {
        if page == .weekly {
            if !dataLoaded { return nil }
            
            if let lowestWeightData = WeeklyWeightData.min(by: {
                $0.weightAvg ?? .greatestFiniteMagnitude < $1.weightAvg ?? .greatestFiniteMagnitude
            }) {
                return lowestWeightData
            }
        } else {
            if !dataLoaded { return nil }
            
            if let lowestWeightData = WeightData.min(by: {
                $0.weightAvg ?? .greatestFiniteMagnitude < $1.weightAvg ?? .greatestFiniteMagnitude
            }) {
                return lowestWeightData
            }
        }

        return nil
    }
    
    func maxWeightData(_ page: WeightPage) -> WeightChartData? {
        if page == .weekly {
            if !dataLoaded { return nil }

            return WeeklyWeightData.max(by: { $0.weightAvg ?? 0.0 < $1.weightAvg ?? 0.0})
        } else {
            if !dataLoaded { return nil }

            return WeightData.max(by: { $0.weightAvg ?? 0.0 < $1.weightAvg ?? 0.0})
        }        
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

}

extension WeightDataViewModel {

    private func average(days: Int) -> Double {
        guard dataLoaded else { return 0 }
        let values = WeightData.suffix(days).compactMap(\.weightAvg)
        guard !values.isEmpty else { return 0 }
        return (values.reduce(0, +) / Double(values.count) * 10).rounded() / 10
    }

}

enum WeightPage: Int, Hashable {

    case weekly = 0
    case monthly = 1

}

/// One calendar day's weight average for charts.
struct WeightChartData: Identifiable, Equatable, Sendable {

    let date: Date
    var weightAvg: Double?

    var id: Date { date }

    init(date: Date, weightAvg: Double?) {
        self.date = Calendar.current.startOfDay(for: date)
        self.weightAvg = weightAvg
    }

}
