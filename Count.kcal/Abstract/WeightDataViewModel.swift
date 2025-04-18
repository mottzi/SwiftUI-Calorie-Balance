import SwiftUI

enum WeightPage: Int, Hashable
{
    case weekly = 0
    case monthly = 1
}

struct WeightChartData: Identifiable
{
    let id = UUID()
    
    var date: Date
    var weightAvg: Double?
}

@Observable class WeightDataViewModel
{
    @ObservationIgnored private let hk = HKRepository.shared
    @ObservationIgnored private let referenceDate = Date.now
    
    var WeightData: [WeightChartData] = []
    
    var dataLoaded: Bool
    {
        return WeightData.count >= 30
    }
    
    var WeeklyWeightData: [WeightChartData]
    {
        if !dataLoaded { return [] }
        
        var returnData: [WeightChartData] = []
    
        for index in (WeightData.count - 1 - 6) ... WeightData.count - 1
        {
            returnData.append(WeightData[index])
        }

        return returnData
    }
    
    var weightLatest: Double?
    var weightLatestDate: Date?
    
    var weightAvg30: Double
    {
        if !dataLoaded { return 0.0 }
        
        var data: [WeightChartData] = []
        
        for index in (WeightData.count - 1 - 29) ... WeightData.count - 1
        {
            data.append(WeightData[index])
        }
        
        data = data.filter({ $0.weightAvg != nil })
        
        var avg: Double = 0.0
        
        if data.count > 0
        {
            var cum: Double = 0.0
            
            for validData in data
            {
                cum += validData.weightAvg!
            }
            
            avg = round(cum / Double(data.count) * 10) / 10.0
        }
        
        return avg
    }
    
    var weightAvg7: Double
    {
        if !dataLoaded { return 0.0 }
        
        var data: [WeightChartData] = []
        
        for index in (WeightData.count - 1 - 6) ... WeightData.count - 1
        {
            data.append(WeightData[index])
        }
        
        data = data.filter({ $0.weightAvg != nil })
        
        var avg: Double = 0.0
        
        if data.count > 0
        {
            var cum: Double = 0.0
            
            for validData in data
            {
                cum += validData.weightAvg!
            }
                        
            avg = round(cum / Double(data.count) * 10) / 10.0
        }
        
        return avg
    }
    
    func fetchData() async
    {
        let data = await hk.fetchInitialAvgWeightData(for: self.referenceDate)
        
        let (latestValue, latestDate) = await hk.fetchLatestWeightData()
            
        await MainActor.run
        {
            self.WeightData = data
            self.weightLatest = latestValue
            self.weightLatestDate = latestDate
        }
        
        // printData()
    }
    
    func validData(_ page: WeightPage) -> [WeightChartData]
    {
        if page == .weekly
        {
            return WeeklyWeightData.filter({ $0.weightAvg != nil })
        }
        else // if page == .monthly
        {
            return WeightData.filter({ $0.weightAvg != nil })
        }
    }
    
    /*func randomizeWeightData(range: ClosedRange<Double>)
    {
        for (index, _) in self.WeightData.enumerated()
        {
            if WeightData[index].date > referenceDate
            {
                self.WeightData[index].weightAvg = nil
            }
            else if(Int.random(in: 1...100) <= 25)
            {
                self.WeightData[index].weightAvg = nil
            }
            else
            {
                self.WeightData[index].weightAvg = round(Double.random(in: range) * 10) / 10.0
            }
        }
    }*/
    
    func randomizeWeightData(start: Double, end: Double)
    {
        assert(start > end, "Start weight must be greater than end weight")
        
        // Set latest weight to the target end weight (lowest)
        weightLatest = end
        weightLatestDate = .now.subtractDays(Int.random(in: 1...20))
        
        let numberOfEntries: Int = self.WeightData.count
        
        // Iterate through the array from start to end
        // Index 0 should be oldest (highest weight)
        // Last index should be newest (lowest weight)
        for index in 0..<numberOfEntries
        {
            let setNil: Bool = Double.random(in: 0.0...1.0) < 0.25
            
            if setNil
            {
                self.WeightData[index].weightAvg = nil
            }
            else
            {
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
                
                self.WeightData[index].weightAvg = baseWeight + wiggle
            }
        }
    }
    
    func printData()
    {
        if !dataLoaded { return }
        
        var str = ""
        
        print("*** printing all data:")
        for (index, element) in self.WeightData.enumerated()
        {
            if element.weightAvg == nil
            {
                str = "nil"
            }
            else
            {
                str = String(element.weightAvg!)
            }

            print("*** \(index + 1). element -date = \(element.date.shortDate) -weight = \(str)")
        }
        
        print("*** printing weekly data:")
        for (index, element) in self.WeeklyWeightData.enumerated()
        {
            if element.weightAvg == nil
            {
                str = "nil"
            }
            else
            {
                str = String(element.weightAvg!)
            }

            print("*** \(index + 1). element -date = \(element.date.shortDate) -weight = \(str)")
        }
    }

    func firstWeightValue(_ page: WeightPage) -> Double?
    {
        if page == .weekly
        {
            if let firstValidElement = WeeklyWeightData.first(where: { $0.weightAvg != nil })
            { return firstValidElement.weightAvg }
        }
        else // if page == .monthly
        {
            if let firstValidElement = WeightData.first(where: { $0.weightAvg != nil })
            { return firstValidElement.weightAvg }
        }
        
        return nil
    }
    
    func lastWeightValue(_ page: WeightPage) -> Double?
    {
        if page == .weekly
        {
            if let lastValidElement = WeeklyWeightData.last(where: { $0.weightAvg != nil })
            { return lastValidElement.weightAvg }
        }
        else // if page == .monthly
        {
            if let lastValidElement = WeightData.last(where: { $0.weightAvg != nil })
            { return lastValidElement.weightAvg }
        }
        
        return nil
    }
    
    func minWeightData(_ page: WeightPage) -> WeightChartData?
    {
        if page == .weekly
        {
            if !dataLoaded { return nil }
            
            if let lowestWeightData = WeeklyWeightData.min(by: { $0.weightAvg ?? .greatestFiniteMagnitude < $1.weightAvg ?? .greatestFiniteMagnitude })
            {
                return lowestWeightData
            }
        }
        else // if page == .monthly
        {
            if !dataLoaded { return nil }
            
            if let lowestWeightData = WeightData.min(by: { $0.weightAvg ?? .greatestFiniteMagnitude < $1.weightAvg ?? .greatestFiniteMagnitude })
            {
                return lowestWeightData
            }
        }

        return nil
    }
    
    func maxWeightData(_ page: WeightPage) -> WeightChartData?
    {
        if page == .weekly
        {
            if !dataLoaded { return nil }

            return WeeklyWeightData.max(by: { $0.weightAvg ?? 0.0 < $1.weightAvg ?? 0.0})
        }
        else // if page == .monthly
        {
            if !dataLoaded { return nil }

            return WeightData.max(by: { $0.weightAvg ?? 0.0 < $1.weightAvg ?? 0.0})
        }        
    }
    
    func getYRange(_ page: WeightPage) -> ClosedRange<Int>
    {
        return getYBottomRange(page) ... getYTopRange(page)
    }

    func createYRangeArray(_ page: WeightPage) -> [Int]
    {
        var rangeArray: [Int] = []

        for num in getYBottomRange(page) ... getYTopRange(page)
        {
            rangeArray.append(num)
        }
        
        return rangeArray
    }

    func getYTopRange(_ page: WeightPage) -> Int
    {
        switch page
        {
            case .weekly:  Int(floor(maxWeightData(page)?.weightAvg ?? 0.0) + 1.0)
            case .monthly: Int(round(maxWeightData(page)?.weightAvg ?? 0.0) + 1.0)
        }
    }

    func getYBottomRange(_ page: WeightPage) -> Int
    {
        switch page
        {
            case .weekly:  Int(ceil(minWeightData(page)?.weightAvg ?? 0.0) - 1.0)
            case .monthly: Int(round(minWeightData(page)?.weightAvg ?? 0.0) - 1.0)
        }
    }
}
