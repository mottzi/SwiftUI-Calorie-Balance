import Foundation

/// Daily energy, nutrient, step, and calculated balance values.
struct HealthData: Equatable {

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

    /// Records the source used for this snapshot, including while the mode changes.
    var isSampleData: Bool = false

    /// Selects actual active energy for the midnight estimate.
    var usesMeasuredActiveAtMidnight: Bool = true
    
    /// Energy recorded for the sample date.
    var now: EnergyBalance {
        EnergyBalance(active: burnedActive, resting: burnedPassive, consumed: consumed)
    }

    /// End-of-day estimate using the active source saved with this snapshot.
    var midnight: EnergyBalance {
        EnergyBalance(
            active: burnedActiveMidnight,
            resting: burnedPassive,
            restingRemaining: burnedPassiveRemaining,
            consumed: consumed
        )
    }

    var balanceNow: Int { now.balance }

    /// Active energy used by the midnight balance and graphs.
    var burnedActiveMidnight: Int { usesMeasuredActiveAtMidnight ? burnedActive : burnedActive7 }

    var balanceMidnight: Int { midnight.balance }
    
    var burnedPassiveRemaining: Int { max(burnedPassive7 - burnedPassive, 0) }

}

extension HealthData {

    static func example(for date: Date, balance: BalanceOption = .deficit, random: Bool = false) -> HealthData {
        if random {
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
        
        if balance == .deficit {
            return HealthData(
                date: date,
                lastDataSync: nil,
                burnedActive: 1500,
                burnedActive7: 0,
                burnedPassive: 2130,
                burnedPassive7: 2500,
                consumed: 2380,
                protein: 100,
                carbs: 80,
                fats: 100,
                steps: 6809
            )
        } else {
            return HealthData(
                date: date,
                lastDataSync: nil,
                burnedActive: 400,
                burnedActive7: 0,
                burnedPassive: 1850,
                burnedPassive7: 2200,
                consumed: 2700,
                protein: 100,
                carbs: 80,
                fats: 100,
                steps: 1270
            )
        }
    }
    
    static func empty(for date: Date) -> HealthData {
        HealthData(
            date: date,
            lastDataSync: nil,
            burnedActive: 0,
            burnedActive7: 0,
            burnedPassive: 0,
            burnedPassive7: 0,
            consumed: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            steps: 0
        )
    }

}

enum BalanceOption {

    case deficit
    case surplus

}
