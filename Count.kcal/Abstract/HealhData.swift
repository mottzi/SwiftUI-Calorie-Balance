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
    static func example(for date: Date, balance: BalanceOption = .deficit) -> HealthData
    {
        if balance == .deficit
        {
            HealthData(date: date, lastDataSync: nil, burnedActive: 500, burnedActive7: 0, burnedPassive: 2130, burnedPassive7: 2500, consumed: 1880, protein: 100, carbs: 80, fats: 100)
        }
        else
        {
            HealthData(date: date, lastDataSync: nil, burnedActive: 400, burnedActive7: 0, burnedPassive: 1850, burnedPassive7: 2200, consumed: 2700, protein: 100, carbs: 80, fats: 100)
        }
    }
    
    static func empty(for date: Date) -> HealthData
    {
        HealthData(date: date, lastDataSync: nil, burnedActive: 0, burnedActive7: 0, burnedPassive: 0, burnedPassive7: 0, consumed: 0, protein: 0, carbs: 0, fats: 0)
    }
}
