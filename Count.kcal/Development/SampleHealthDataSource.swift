#if DEBUG && os(iOS)
import HealthKit

/// Supplies measurements without creating or accessing an HKHealthStore.
struct SampleHealthDataSource: HealthDataSource {

    let now: Date
    let calendar: Calendar

    init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        var sums: [Date: Double] = [:]
        for day in days(from: start, to: end) {
            let sample = SampleHealthDay(date: day, now: now, calendar: calendar)
            sums[day] = sample?.quantity(type)?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData] {
        days(from: start, to: end).map { date in
            let sample = SampleHealthDay(date: date, now: now, calendar: calendar)
            return WeightChartData(date: date, weightAvg: sample?.quantity(.bodyMass)?.doubleValue(for: unit))
        }
    }

    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?) {
        let date = min(end, now)
        guard let sample = SampleHealthDay(date: date, now: now, calendar: calendar) else { return (nil, nil) }
        // A historical query before its weighing time must use the previous day.
        if sample.weightDate > end {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date),
                  let earlier = SampleHealthDay(date: previous, now: now, calendar: calendar) else { return (nil, nil) }
            return (earlier.quantity(.bodyMass)?.doubleValue(for: unit), earlier.weightDate)
        }
        return (sample.quantity(.bodyMass)?.doubleValue(for: unit), sample.weightDate)
    }

    func requestPermission() async -> Bool { true }

}

extension SampleHealthDataSource {

    private func days(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day < end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

}
#endif
