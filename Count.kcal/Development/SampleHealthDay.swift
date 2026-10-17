#if DEBUG && (os(iOS) || os(watchOS))
import HealthKit

/// One repeatable dataset for app-local samples and simulator HealthKit seeding.
struct SampleHealthDay {

    let date: Date
    let end: Date
    let weightDate: Date
    let energyFraction: Double
    let variation: Int
    let daysAgo: Int

    init?(date: Date, now: Date = .now, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let age = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        guard (0..<Self.historyDays).contains(age),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        self.date = day
        end = min(now, nextDay.addingTimeInterval(-1))
        weightDate = min(end, calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!)
        energyFraction = age == 0 ? min(max(now.timeIntervalSince(day) / nextDay.timeIntervalSince(day), 0), 1) : 1
        // Stable calendar-day variation, shared by separate app and widget processes.
        let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        variation = ordinal % 28
        daysAgo = age
    }

    func quantity(_ type: HKQuantityTypeIdentifier) -> HKQuantity? {
        let value: Double
        let unit: HKUnit
        switch type {
            case .basalEnergyBurned:
                value = Double(1640 + (variation * 37) % 180) * energyFraction
                unit = .kilocalorie()
            case .activeEnergyBurned:
                value = Double(350 + (variation * 53) % 380) * energyFraction
                unit = .kilocalorie()
            case .dietaryEnergyConsumed:
                value = Double(1850 + (variation * 67) % 700) * energyFraction
                unit = .kilocalorie()
            case .dietaryProtein:
                value = Double(100 + (variation * 7) % 45) * energyFraction
                unit = .gram()
            case .dietaryCarbohydrates:
                value = Double(190 + (variation * 11) % 65) * energyFraction
                unit = .gram()
            case .dietaryFatTotal:
                value = Double(58 + (variation * 3) % 30) * energyFraction
                unit = .gram()
            case .stepCount:
                value = Double(5500 + (variation * 431) % 7500) * energyFraction
                unit = .count()
            case .bodyMass:
                value = 79.7 + Double(daysAgo) * 0.025 + sin(Double(variation)) * 0.15
                unit = .gramUnit(with: .kilo)
            default: return nil
        }
        return HKQuantity(unit: unit, doubleValue: value)
    }

}

extension SampleHealthDay {

    static let historyDays = 200

}

/// A complete screenshot fixture, independent of the time the app is opened.
struct MarketingHealthProfile: Sendable {

    let balanceGoal: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatsGoal: Int

    /// Round fixture energy in kcal before HealthKit converts it to the requested unit.
    private func roundedEnergy(_ value: Double) -> Double { (value / 10).rounded() * 10 }

    func quantity(_ type: HKQuantityTypeIdentifier, on day: SampleHealthDay) -> HKQuantity? {
        let index = day.daysAgo % 7
        let goal = max(0, balanceGoal)
        let target = roundedEnergy(goal * 1.2)
        // Keep intake positive even with an unusually large saved deficit goal.
        let resting = max(1_900, roundedEnergy(goal * 1.4 + 1_000))
        let active = [700.0, 820, 610, 760, 540, 870, 600][index]
        let remaining = day.daysAgo == 0 ? min(320, roundedEnergy(target * 0.6)) : 0
        let balances = [1.2, 1.4, 1.1, -0.7, 0.65, -1.8, 0.95]
        let balance = day.daysAgo == 0 ? target : roundedEnergy(max(200, goal) * balances[index])
        let eaten = Int(resting + active - balance)
        let value: Double
        let unit: HKUnit
        switch type {
        case .basalEnergyBurned:
            value = resting - remaining
            unit = .kilocalorie()
        case .activeEnergyBurned:
            value = active
            unit = .kilocalorie()
        case .dietaryEnergyConsumed:
            value = Double(eaten)
            unit = .kilocalorie()
        case .dietaryProtein:
            value = Double(macros(for: eaten, isToday: day.daysAgo == 0).protein)
            unit = .gram()
        case .dietaryCarbohydrates:
            value = Double(macros(for: eaten, isToday: day.daysAgo == 0).carbs)
            unit = .gram()
        case .dietaryFatTotal:
            value = Double(macros(for: eaten, isToday: day.daysAgo == 0).fats)
            unit = .gram()
        case .stepCount:
            value = [8_640.0, 10_230, 7_810, 9_470, 6_920, 11_140, 8_120][index]
            unit = .count()
        default:
            return day.quantity(type)
        }
        return HKQuantity(unit: unit, doubleValue: value)
    }

    /// Whole grams must satisfy 4C + 9F + 4P exactly, including after display rounding.
    private func macros(for calories: Int, isToday: Bool) -> (carbs: Int, fats: Int, protein: Int) {
        let goals = [max(1, carbsGoal), max(1, fatsGoal), max(1, proteinGoal)]
        let preferred = [Double(goals[0]) * 0.88, Double(goals[1]) * 0.78, Double(goals[2]) * 0.94]
        let scale = Double(calories) / (preferred[0] * 4 + preferred[1] * 9 + preferred[2] * 4)
        let target = preferred.map { $0 * scale }

        func fit(withinGoals: Bool) -> (carbs: Int, fats: Int, protein: Int)? {
            let minimum = withinGoals ? goals.map { Int(ceil(Double($0) * 0.6)) } : [0, 0, 0]
            let maximum = withinGoals ? goals : [calories / 4, calories / 9, calories / 4]
            var best: (carbs: Int, fats: Int, protein: Int)?
            var bestScore = Double.infinity
            for fats in minimum[1]...maximum[1] {
                let remainder = calories - fats * 9
                guard remainder >= 0, remainder % 4 == 0 else { continue }
                let grams = remainder / 4
                let lower = max(minimum[0], grams - maximum[2])
                let upper = min(maximum[0], grams - minimum[2])
                guard lower <= upper else { continue }
                let carbs = min(upper, max(lower, Int((Double(grams) * target[0] / (target[0] + target[2])).rounded())))
                let protein = grams - carbs
                let score = zip([carbs, fats, protein], target).enumerated().reduce(0.0) { sum, item in
                    sum + pow((Double(item.element.0) - item.element.1) / Double(goals[item.offset]), 2)
                }
                if score < bestScore {
                    bestScore = score
                    best = (carbs, fats, protein)
                }
            }
            return best
        }

        // Unusual saved goals can make the percentage limits impossible. Calorie
        // consistency takes priority, as it does on historical surplus days.
        if isToday, let bounded = fit(withinGoals: true) { return bounded }
        return fit(withinGoals: false) ?? (calories / 4, 0, 0)
    }

}
#endif
