#if DEBUG && targetEnvironment(simulator) && os(iOS)
import HealthKit

/// Explicit integration-test tool. This type is never compiled for a physical device.
@MainActor
enum SimulatorHealthSeeder {

    static func seed() async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { throw SeedError.healthKitUnavailable }
        let store = HKHealthStore()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .basalEnergyBurned, .activeEnergyBurned, .dietaryEnergyConsumed,
            .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal, .stepCount, .bodyMass
        ]
        let types = identifiers.map(HKQuantityType.init)
        try await store.requestAuthorization(toShare: Set(types), read: Set(types))
        guard types.allSatisfy({ store.authorizationStatus(for: $0) == .sharingAuthorized }) else {
            throw SeedError.writePermissionDenied
        }

        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let version = Int(now.timeIntervalSince1970)
        var samples: [HKObject] = []
        for daysAgo in (0..<SampleHealthDay.historyDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let day = SampleHealthDay(date: date, now: now, calendar: calendar,
                                            profile: HealthDataMode.currentSampleProfile) else { continue }
            for identifier in identifiers {
                guard let quantity = day.quantity(identifier) else { continue }
                let start = identifier == .bodyMass ? day.weightDate : day.date
                let end = identifier == .bodyMass ? day.weightDate : day.end
                samples.append(HKQuantitySample(
                    type: HKQuantityType(identifier),
                    quantity: quantity,
                    start: start,
                    end: end,
                    metadata: [
                        HKMetadataKeySyncIdentifier:
                            "CountKcal.Simulator.\(identifier.rawValue).\(Int(date.timeIntervalSince1970))",
                        HKMetadataKeySyncVersion: NSNumber(value: version)
                    ]
                ))
            }
        }
        try await store.save(samples)
        HealthDataMode.shared.invalidateData()
        return samples.count
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--health-data-seed-simulator"),
              !HealthDataMode.isSampleDataEnabled else { return }
        do { print("[SimulatorHealthSeed] Submitted \(try await seed()) HealthKit samples") }
        catch { print("[SimulatorHealthSeed] Failed: \(error)") }
    }

    private enum SeedError: Error {

        case healthKitUnavailable
        case writePermissionDenied
    }

}
#endif
