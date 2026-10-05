import Foundation

/// Energy values for a completed calendar day, before manual choices apply.
struct ProgressDay: Identifiable, Equatable, Sendable {
    let date: Date
    let active: Double
    let resting: Double
    let food: Double
    var usesCustomEnergy = false
    var id: Date { date }
}

/// One day's eligibility for the average deficit.
enum DayEligibility: Equatable {

    case included
    case fasting
    case excluded
    case missingFood
    case missingEnergy
    case fastingConflict

    static func resolve(_ day: ProgressDay, choice: DayChoice) -> Self {
        if choice == .excluded { return .excluded }
        if choice == .fasting && day.food > 0 { return .fastingConflict }
        if !day.resting.isFinite || day.resting < 0 || !day.active.isFinite || day.active < 0 {
            return .missingEnergy
        }
        if day.usesCustomEnergy ? day.active + day.resting <= 0 : day.resting == 0 { return .missingEnergy }
        if !day.food.isFinite || day.food < 0 { return .missingFood }
        if choice == .fasting { return .fasting }
        if day.food == 0 { return .missingFood }
        return .included
    }

    var isIncluded: Bool { self == .included || self == .fasting }

}

/// Calendar bounds and labels for a completed seven- or thirty-day period.
enum ProgressPeriod: Int, CaseIterable {

    case week = 7
    case month = 30

    func interval(endingBefore today: Date, calendar: Calendar = .current) -> DateInterval {
        let end = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -rawValue, to: end)!
        return DateInterval(start: start, end: end)
    }

}

/// Unrounded period calculations; missing measurements never count as zero.
struct ProgressSummary {

    let days: [(day: ProgressDay, eligibility: DayEligibility)]
    let weightChange: Double?
    let currentWeightDays: Int
    let previousWeightDays: Int

    init(
        period: ProgressPeriod,
        today: Date,
        energy: [ProgressDay],
        weights: [Date: Double],
        choices: [String: DayChoice],
        calendar: Calendar = .current
    ) {

        let interval = period.interval(endingBefore: today, calendar: calendar)
        days = energy.filter { $0.date >= interval.start && $0.date < interval.end }.map {
            ($0, DayEligibility.resolve($0, choice: choices[DayKey.make($0.date, calendar: calendar)] ?? .automatic))
        }
        let previousStart = calendar.date(byAdding: .day, value: -period.rawValue, to: interval.start)!
        let current = weights.filter { $0.key >= interval.start && $0.key < interval.end }.values.filter {
            $0.isFinite && $0 > 0
        }
        let previous = weights.filter { $0.key >= previousStart && $0.key < interval.start }.values.filter {
            $0.isFinite && $0 > 0
        }
        currentWeightDays = current.count
        previousWeightDays = previous.count
        weightChange = current.count >= 2 && previous.count >= 2
            ? current.reduce(0, +) / Double(current.count) - previous.reduce(0, +) / Double(previous.count)
            : nil
    }

    var includedDays: Int { days.filter { $0.eligibility.isIncluded }.count }

    var averageDeficit: Double? {
        let included = days.filter { $0.eligibility.isIncluded }
        guard included.count >= 2 else { return nil }
        return included.reduce(0) { $0 + $1.day.active + $1.day.resting - $1.day.food } / Double(included.count)
    }

}
