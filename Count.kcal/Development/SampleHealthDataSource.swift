#if DEBUG && (os(iOS) || os(watchOS))
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
        await waitForLaunchFixture()
        var sums: [Date: Double] = [:]
        for day in days(from: start, to: end) {
            let sample = SampleHealthDay(date: day, now: now, calendar: calendar)
            sums[day] = sample?.quantity(type)?.doubleValue(for: unit) ?? 0
        }
        return sums
    }

    func weights(from start: Date, to end: Date, unit: HKUnit) async -> [WeightChartData] {
        await waitForLaunchFixture()
        return days(from: start, to: end).map { date in
            let sample = SampleHealthDay(date: date, now: now, calendar: calendar)
            return WeightChartData(date: date, weightAvg: sample?.quantity(.bodyMass)?.doubleValue(for: unit))
        }
    }

    /// Distributes sample energy into meals and activity periods for the contour.
    func energyIntervals(
        _ type: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date,
        unit: HKUnit
    ) async -> [Date: Double] {

        guard end > start else { return [:] }
        guard let sample = SampleHealthDay(date: start, now: min(now, end), calendar: calendar),
              let quantity = sample.quantity(type) else { return [:] }
        let count = Int(ceil(min(now, end).timeIntervalSince(start) / 900))
        guard count > 0 else { return [:] }
        var weights = (0..<count).map { index in
            let hour = (Double(index) + 0.5) / 4
            if type == .activeEnergyBurned {
                return 0.15 + exp(-pow((hour - 7.5) / 0.7, 2)) * 3 + exp(-pow((hour - 13) / 1.0, 2)) * 2
            }
            return 1.0
        }
        if type == .dietaryEnergyConsumed {
            weights = Array(repeating: 0, count: count)
            let meals = [(30, 0.26), (50, 0.35), (64, 0.12), (78, 0.23), (88, 0.04)]
            for (index, weight) in meals where index < count { weights[index] = weight }
            if weights.reduce(0, +) == 0 { weights[count - 1] = 1 }
        }
        let total = weights.reduce(0, +)
        return Dictionary(uniqueKeysWithValues: weights.enumerated().map { index, weight in
            (start.addingTimeInterval(Double(index) * 900), quantity.doubleValue(for: unit) * weight / total)
        })
    }

    func latestWeight(before end: Date, unit: HKUnit) async -> (Double?, Date?) {
        await waitForLaunchFixture()
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

    /// Simulator QA can hold queries open to inspect the first-load presentation.
    private func waitForLaunchFixture() async {
        #if targetEnvironment(simulator)
        guard let value = ProcessInfo.processInfo.environment["COUNT_SAMPLE_QUERY_DELAY"],
              let seconds = Double(value), seconds.isFinite, seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(min(seconds, 10)))
        #endif
    }

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
