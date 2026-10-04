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
#endif
