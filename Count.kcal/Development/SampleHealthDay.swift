#if DEBUG && (os(iOS) || os(watchOS))
import HealthKit

/// Saved identities for repeatable sample measurements across app processes.
enum SampleHealthProfile: String, CaseIterable, Identifiable, Sendable {

    case active
    case lowActivity
    case maintenance
    case irregularLogging

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .lowActivity: "Low activity"
        case .maintenance: "Maintenance"
        case .irregularLogging: "Irregular logging"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .active: "Higher activity, regular food logging, and gradual weight loss."
        case .lowActivity: "Fewer steps, lower energy expenditure, and a small calorie surplus."
        case .maintenance: "Intake close to energy expenditure and a steady weight."
        case .irregularLogging: "Variable food logging, including days with no food recorded."
        }
    }

    fileprivate var seed: Int {
        switch self {
        case .active: 17
        case .lowActivity: 43
        case .maintenance: 71
        case .irregularLogging: 97
        }
    }

    fileprivate var baseline: (resting: Double, active: Double, intake: Double, steps: Double,
                               weight: Double, dailyWeightChange: Double) {
        switch self {
        case .active: (1850, 800, 2200, 12000, 79.7, -0.008)
        case .lowActivity: (1550, 220, 2050, 3500, 68.4, 0.004)
        case .maintenance: (1750, 450, 2200, 7500, 73.2, 0)
        case .irregularLogging: (1700, 380, 1950, 6200, 85.6, -0.003)
        }
    }

}

/// One repeatable dataset for app-local samples and simulator HealthKit seeding.
struct SampleHealthDay {

    let date: Date
    let end: Date
    let weightDate: Date
    let energyFraction: Double
    let variation: Int
    let daysAgo: Int
    let profile: SampleHealthProfile
    private let ordinal: Int

    init?(date: Date, now: Date = .now, calendar: Calendar = .current,
          profile: SampleHealthProfile = .active) {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let age = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        guard (0..<Self.historyDays).contains(age),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        self.date = day
        end = min(now, nextDay.addingTimeInterval(-1))
        weightDate = min(end, calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!)
        energyFraction = age == 0 ? min(max(now.timeIntervalSince(day) / nextDay.timeIntervalSince(day), 0), 1) : 1
        let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        self.ordinal = ordinal
        self.profile = profile
        variation = (ordinal + profile.seed) % 28
        daysAgo = age
    }

    func quantity(_ type: HKQuantityTypeIdentifier) -> HKQuantity? {
        let baseline = profile.baseline
        let intake = loggedIntake
        let value: Double
        let unit: HKUnit
        switch type {
            case .basalEnergyBurned:
                value = (baseline.resting + noise(1) * 60) * energyFraction
                unit = .kilocalorie()
            case .activeEnergyBurned:
                value = baseline.active * (1 + noise(2) * 0.35) * energyFraction
                unit = .kilocalorie()
            case .dietaryEnergyConsumed:
                value = intake * energyFraction
                unit = .kilocalorie()
            case .dietaryProtein:
                value = intake * 0.25 / 4 * energyFraction
                unit = .gram()
            case .dietaryCarbohydrates:
                value = intake * 0.45 / 4 * energyFraction
                unit = .gram()
            case .dietaryFatTotal:
                value = intake * 0.30 / 9 * energyFraction
                unit = .gram()
            case .stepCount:
                // Steps and active energy follow the same daily activity variation.
                value = baseline.steps * (1 + noise(2) * 0.35) * energyFraction
                unit = .count()
            case .bodyMass:
                // Gregorian day 739617 is January 1, 2026. Historical weights stay fixed as today moves.
                value = baseline.weight + Double(ordinal - 739617) * baseline.dailyWeightChange + noise(4) * 0.2
                unit = .gramUnit(with: .kilo)
            default: return nil
        }
        return HKQuantity(unit: unit, doubleValue: value)
    }

    private var loggedIntake: Double {
        let intake = profile.baseline.intake + noise(3) * 180
        guard profile == .irregularLogging else { return intake }
        switch variation % 5 {
        case 0: return 0
        case 1: return intake * 0.4
        case 2: return intake * 0.7
        default: return intake
        }
    }

    /// Integer arithmetic stays identical across launches, devices, and Swift hash seeds.
    private func noise(_ salt: Int) -> Double {
        let value = (ordinal * (37 + salt * 12) + profile.seed * (101 + salt * 18)) % 997
        return Double(value) / 498 - 1
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
        case .bodyMass:
            let variation = [0.0, 0.01, -0.01, 0.015, -0.005, 0.005, -0.015][index]
            value = 79.7 + Double(day.daysAgo) * 0.07 + variation
            unit = .gramUnit(with: .kilo)
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
