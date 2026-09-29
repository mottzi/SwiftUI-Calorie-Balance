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

    /// Selects actual active energy for the midnight estimate.
    var usesAppleActiveAtMidnight: Bool = true
    
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
    var burnedActiveMidnight: Int { usesAppleActiveAtMidnight ? burnedActive : burnedActive7 }

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

#if DEBUG && targetEnvironment(simulator)
/// Repeatable, in-memory dashboard data for simulator layout checks. Launch with
/// --seed-dashboard-fixture; production builds never include this path.
enum SimulatorDashboardFixture {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--seed-dashboard-fixture")
    }

    /// Optional stress case for all seven recent balance labels.
    static var usesFourDigitBalances: Bool {
        ProcessInfo.processInfo.arguments.contains("--week-balance-four-digits")
    }

    static func prepareSettings() {
        guard isEnabled else { return }
        let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")
        defaults?.set(false, forKey: "showWelcome")
        defaults?.set(1, forKey: "dataSource")
        defaults?.set(0, forKey: "weightGoal")
        defaults?.set(1, forKey: "appBackground")
        defaults?.set("kcal", forKey: "energyUnit")
        defaults?.set("kg", forKey: "weightUnit")
        defaults?.set(1_650, forKey: "customCalPassive")
        defaults?.set(400, forKey: "customCalActive")
        defaults?.set(usesFourDigitBalances ? 1_200 : 300, forKey: "balanceGoal")
        defaults?.set(150, forKey: "carbsGoal")
        defaults?.set(65, forKey: "fatsGoal")
        defaults?.set(110, forKey: "proteinGoal")
        defaults?.set(10_000, forKey: "stepsGoal")
    }

    static func sample(for date: Date) -> HealthData {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: .now)
        let daysAgo = max(0, Calendar.current.dateComponents([.day], from: day, to: today).day ?? 0)
        let variation = daysAgo % 7
        let isToday = day == today

        var sample = HealthData(
            date: day,
            lastDataSync: isToday ? .now : Calendar.current.date(byAdding: .hour, value: 18, to: day),
            burnedActive: isToday ? 278 : 340 + variation * 37,
            burnedActive7: 420,
            burnedPassive: isToday ? 1_120 : 1_650 + variation * 25,
            burnedPassive7: 1_650,
            consumed: isToday ? 1_236 : 1_670 + variation * 64,
            protein: isToday ? 92 : 105 + variation * 4,
            carbs: isToday ? 138 : 180 + variation * 7,
            fats: isToday ? 53 : 62 + variation * 3,
            steps: isToday ? 6_421 : 7_600 + variation * 430
        )

        if usesFourDigitBalances {
            let balances = [1_888, 1_587, 1_085, 1_242, 1_219, 1_196, 1_173]
            let balance = balances[variation]
            sample.burnedActive = 1_500
            sample.burnedPassive = isToday ? 1_120 : 1_650
            sample.consumed = 1_500 + 1_650 - balance
        }
        return sample
    }

    static func weightHistory() -> [WeightChartData] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<37).reversed().compactMap { daysAgo in
            guard let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }
            return WeightChartData(date: day, weightAvg: 79.6 + Double(daysAgo) * 0.045)
        }
    }

}
#endif
