import SwiftUI
import WidgetKit
import Observation
import WatchConnectivity

@Observable class HealthInterface: Hashable
{
    @ObservationIgnored private let AppSettings = Settings.shared
    @ObservationIgnored private let hkRep = HKRepository.shared
    @ObservationIgnored var CachedSample: HealthData?
    @ObservationIgnored var CacheDate: Date?
//    @ObservationIgnored let RefreshWatchWhenReached = 200
    
    var sample: HealthData
    var isTodayPage: Bool { self.sample.date.isToday }
        
    func updateMetrics(cache: Bool = false) async
    {
//        #if DEBUG
//        await self.randomizeHealthData()
//        return
//        #endif
        // (1) use cached data if last cache is younger than 180 seconds
        if cache, let d = self.CacheDate, abs(d.timeIntervalSince(.now)) <  3 * 60, let c = self.CachedSample
        {
            await MainActor.run
            {
                withAnimation(.snappy)
                {
                    self.sample.burnedActive = c.burnedActive
                    self.sample.burnedPassive = c.burnedPassive
                    self.sample.burnedPassive7 = c.burnedPassive7
                    self.sample.consumed = c.consumed
                    self.sample.protein = c.protein
                    self.sample.carbs = c.carbs
                    self.sample.fats = c.fats
                    self.sample.steps = c.steps
                }
            }
            
            return
        }
        
        // (2) fetch data from HealthKit if cache expired
        // prepare async calls
        async let activeFetch = hkRep.cumDataToday(fetch: .activeEnergyBurned, for: self.sample.date)
        async let passiveFetch = hkRep.cumDataToday(fetch: .basalEnergyBurned, for: self.sample.date)
        async let passiveAvgFetch = hkRep.cumDataWeek(fetch: .basalEnergyBurned, for: self.sample.date)
        async let consumedFetch = hkRep.cumDataToday(fetch: .dietaryEnergyConsumed, for: self.sample.date)
        async let proteinFetch = hkRep.cumDataToday(fetch: .dietaryProtein, for: self.sample.date)
        async let carbsFetch = hkRep.cumDataToday(fetch: .dietaryCarbohydrates, for: self.sample.date)
        async let fatsFetch = hkRep.cumDataToday(fetch: .dietaryFatTotal, for: self.sample.date)
        async let stepsFetch = hkRep.cumDataToday(fetch: .stepCount, for: self.sample.date)

        
        // execute all async calls concurrently
        let (active, passive, passiveAvg, consumed, protein, carbs, fats, steps) = await (activeFetch, passiveFetch, passiveAvgFetch, consumedFetch, proteinFetch, carbsFetch, fatsFetch, stepsFetch)
        
        // update UI on main "thread"
        await MainActor.run
        {
//            #if os(iOS)
//            var caloricBalanceWillChange: Bool = false
//            
//            if self.sample.consumed != 0 && abs(self.sample.consumed - consumed) >= RefreshWatchWhenReached && self.sample.date.isToday
//            {
//                caloricBalanceWillChange = true
//            }
//            #endif
            
            withAnimation(.snappy)
            {
                // consumed energy is HealthKit-only at the moment
                self.sample.consumed = consumed
                self.sample.protein = protein
                self.sample.carbs = carbs
                self.sample.fats = fats
                self.sample.steps = steps
                
                // custom energy data
                if AppSettings.dataSource == .custom
                {
                    // today -> calculate current energy proportional to linear day progress
                    if self.sample.date.isToday
                    {
                        self.sample.burnedActive = Int((Double(AppSettings.customCalActive) * Date.getDayProgress).rounded())
                        self.sample.burnedPassive = Int((Double(AppSettings.customCalPassive) * Date.getDayProgress).rounded())
                    }
                    // other -> fill energy to max
                    else
                    {
                        self.sample.burnedActive = AppSettings.customCalActive
                        self.sample.burnedPassive = AppSettings.customCalPassive
                    }
                    
                    self.sample.burnedActive7 = AppSettings.customCalActive
                    self.sample.burnedPassive7 = AppSettings.customCalPassive
                }
                // HealthKit energy data
                else
                {
                    self.sample.burnedActive = active
                    self.sample.burnedPassive = passive
                    self.sample.burnedPassive7 = passiveAvg
                }
                
//                #if os(iOS)
//                if caloricBalanceWillChange
//                {
//                    Connectivity.shared.sendBalanceContext(sample: self.sample)
//                }
//                #endif
            }
        }
        
        // save a copy of new data to cache
        var c = HealthData.empty(for: self.sample.date)
        
        c.burnedActive = active
        c.burnedPassive = passive
        c.burnedPassive7 = passiveAvg
        c.consumed = consumed
        c.protein = protein
        c.carbs = carbs
        c.fats = fats
        c.steps = steps
        
        self.CachedSample = c
        self.CacheDate = .now
    }
    
    @MainActor
    func clearData()
    {
        self.sample.burnedActive = 0
        self.sample.burnedActive7 = 0
        self.sample.burnedPassive = 0
        self.sample.burnedPassive7 = 0
        self.sample.consumed = 0
        self.sample.protein = 0
        self.sample.carbs = 0
        self.sample.fats = 0
        self.sample.steps = 0
    }
    
    @MainActor
    func randomizeHealthData()
    {
//        withAnimation(.snappy)
//        {
            self.sample.burnedActive = Int.random(in: 100...1000)
            self.sample.burnedPassive = Int.random(in: 200...2300)
            self.sample.burnedPassive7 = Int.random(in: 1800...2500)
            self.sample.burnedActive7 = Int.random(in: 200...1000)
            self.sample.consumed = Int.random(in: 400...3600)
            self.sample.protein = Int.random(in: 70...200)
            self.sample.carbs = Int.random(in: 180...300)
            self.sample.fats = Int.random(in: 50...80)
            self.sample.steps = Int.random(in: 0...30000)
//        }
    }
    
    init(data: HealthData) { self.sample = data }
    
    init(_ healthData: HealthData) { self.sample = healthData }
    
    static func == (lhs: HealthInterface, rhs: HealthInterface) -> Bool
    {
         lhs.sample.date.isSameDay(as: rhs.sample.date)
    }

    func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.sample.date)
    }
}
