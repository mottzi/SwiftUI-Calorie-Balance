import HealthKit
import WidgetKit

/// One daily contour with the saved energy unit and source mode.
struct EnergyContourEntry: TimelineEntry {

    let date: Date
    let contour: EnergyContour
    let energyUnit: String
    var isSampleData = false

}

/// Measured interval history with the same midnight policy as the calorie dashboard.
struct EnergyContourTimelineProvider: TimelineProvider {

    func getTimeline(in context: Context, completion: @escaping (Timeline<EnergyContourEntry>) -> Void) {
        Task { @MainActor in
            let date = Date.now
            var entry: EnergyContourEntry
            var policy: Policy
            var revision: String
            repeat {
                revision = HealthRepository.shared.revision
                policy = Policy()
                entry = await fetchEntry(date: date, policy: policy)
            } while !Task.isCancelled && (revision != HealthRepository.shared.revision || policy != Policy())
            let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
            completion(Timeline(entries: [entry], policy: .after(min(date.addingTimeInterval(900), midnight))))
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (EnergyContourEntry) -> Void) {
        if context.isPreview { completion(.preview) }
        else { getTimeline(in: context) { completion($0.entries.first ?? .preview) } }
    }

    func placeholder(in context: Context) -> EnergyContourEntry { .preview }

}

extension EnergyContourTimelineProvider {

    @MainActor
    private func fetchEntry(date: Date, policy: Policy) async -> EnergyContourEntry {

        let now = measurementDate(date, hour: policy.sampleHour)
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let repository: HealthRepository
        #if DEBUG
        repository = policy.sampleHour != nil ? HealthRepository(source: SampleHealthDataSource(now: now)) : .shared
        #else
        repository = .shared
        #endif
        let source = repository.dataSource
        let unit: HKUnit = policy.unit == "kJ" ? .jouleUnit(with: .kilo) : .kilocalorie()
        async let active = intervals(source, type: .activeEnergyBurned, start: start, end: now, unit: unit)
        async let passive = intervals(source, type: .basalEnergyBurned, start: start, end: now, unit: unit)
        async let consumed = intervals(source, type: .dietaryEnergyConsumed, start: start, end: now, unit: unit)
        async let average = repository.cumDataWeek(
            fetch: .basalEnergyBurned,
            for: now,
            energyUnit: policy.unit == "kJ" ? .kJ : .kcal
        )
        let values = await (active, passive, consumed, average)
        let burned = values.0.merging(values.1, uniquingKeysWith: +)
        let estimate = policy.usesCustomEnergy
            ? Double(policy.customActive + policy.customPassive)
            : values.0.values.reduce(0, +) + max(values.1.values.reduce(0, +), Double(values.3))
        return EnergyContourEntry(
            date: date,
            contour: EnergyContour(
                start: start,
                end: end,
                now: now,
                burned: policy.usesCustomEnergy ? [:] : burned,
                consumed: values.2,
                estimatedBurned: estimate,
                customBurned: policy.usesCustomEnergy ? estimate : nil,
                balanceGoal: policy.goal,
                isLoss: policy.isLoss
            ),
            energyUnit: policy.unit,
            isSampleData: policy.isSampleData
        )
    }

    private func intervals(
        _ source: any HealthDataSource,
        type: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> [Date: Double] {
        let values = (try? await source.energyIntervals(type, from: start, to: end, unit: unit)) ?? [:]
        return values.filter { $0.key >= start && $0.key < end && $0.value.isFinite && $0.value > 0 }
    }

    private func measurementDate(_ date: Date, hour: Double?) -> Date {
        guard let hour else { return date }
        return Calendar.current.date(
            bySettingHour: Int(hour),
            minute: Int((hour - floor(hour)) * 60),
            second: 0,
            of: date
        )!
    }

}

extension EnergyContourTimelineProvider {

    private struct Policy: Equatable {

        let unit: String
        let source: Int
        let usesCustomEnergy: Bool
        let customActive: Int
        let customPassive: Int
        let goal: Int
        let isLoss: Bool
        let isSampleData: Bool
        var sampleHour: Double?

        @MainActor
        init() {

            let settings = Settings.shared
            unit = settings.energyUnit.rawValue
            source = settings.dataSource.rawValue
            usesCustomEnergy = settings.usesCustomEnergy
            customActive = settings.customCalActive
            customPassive = settings.customCalPassive
            goal = settings.balanceGoal
            isLoss = settings.weightGoal == .lose
            isSampleData = HealthDataMode.isSampleDataEnabled
            #if DEBUG
            if isSampleData,
               let hour = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")?
                .object(forKey: "debugEnergyContourSampleHour") as? Double,
               hour.isFinite, (0..<24).contains(hour) {
                sampleHour = hour
            }
            #endif
        }

    }

}

extension EnergyContourEntry {

    static var preview: EnergyContourEntry {

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let burned = [(6.0, 430.0), (7.5, 240), (10, 470), (12, 330), (14, 350), (16.5, 230)]
        let consumed = [(7.5, 420.0), (12.5, 820), (15.25, 570)]
        return EnergyContourEntry(
            date: .now,
            contour: EnergyContour(
                start: start,
                end: end,
                now: start.addingTimeInterval(16.5 * 3600),
                burned: Dictionary(uniqueKeysWithValues: burned.map {
                    (start.addingTimeInterval($0.0 * 3600 - 900), $0.1)
                }),
                consumed: Dictionary(uniqueKeysWithValues: consumed.map {
                    (start.addingTimeInterval($0.0 * 3600 - 900), $0.1)
                }),
                estimatedBurned: 2950,
                balanceGoal: 500,
                isLoss: true
            ),
            energyUnit: "kcal"
        )
    }

}
