import Foundation

struct HealthData
{
    var date: Date
    var lastDataSync: Date?
    
    var burnedActive: Int
    var burnedActive7: Int

    var burnedPassive: Int
    var burnedPassive7: Int
    
    var consumed: Int
    
    var protein: Int
    var carbs: Int
    var fats: Int
    
    var steps: Int
    
    var balanceNow: Int { burnedPassive + burnedActive - consumed }
    var balanceMidnight: Int { burnedPassive + burnedPassiveRemaining + (Settings.shared.dataSource == .apple ? burnedActive : burnedActive7) - consumed }
    
    var burnedActiveRemaining: Int { max(burnedActive7 - burnedActive, 0) }
    var burnedPassiveRemaining: Int { max(burnedPassive7 - burnedPassive, 0) }
}

enum BalanceOption 
{
    case deficit
    case surplus
}

extension HealthData
{
    static func example(for date: Date, balance: BalanceOption = .deficit, random: Bool = false) -> HealthData
    {
        if random
        {
            var data = HealthData.empty(for: date)
            
            data.burnedActive = Int.random(in: 100...1000)
            data.burnedPassive = Int.random(in: 200...2300)
            data.burnedPassive7 = Int.random(in: 1800...2500)
            data.burnedActive7 = Int.random(in: 200...1000)
            data.consumed = Int.random(in: 400...3600)
            data.protein = Int.random(in: 70...200)
            data.carbs = Int.random(in: 180...300)
            data.fats = Int.random(in: 50...80)
            data.steps = Int.random(in: 0...30000)
            
            return data
        }
        
        if balance == .deficit
        {
            return HealthData(date: date, lastDataSync: nil, burnedActive: 1500, burnedActive7: 0, burnedPassive: 2130, burnedPassive7: 2500, consumed: 2380, protein: 100, carbs: 80, fats: 100, steps: 6809)
        }
        else
        {
            return HealthData(date: date, lastDataSync: nil, burnedActive: 400, burnedActive7: 0, burnedPassive: 1850, burnedPassive7: 2200, consumed: 2700, protein: 100, carbs: 80, fats: 100, steps: 1270)
        }
    }
    
    static func empty(for date: Date) -> HealthData
    {
        HealthData(date: date, lastDataSync: nil, burnedActive: 0, burnedActive7: 0, burnedPassive: 0, burnedPassive7: 0, consumed: 0, protein: 0, carbs: 0, fats: 0, steps: 0)
    }
}
