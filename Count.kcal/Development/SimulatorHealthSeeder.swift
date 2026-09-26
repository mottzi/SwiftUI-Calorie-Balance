#if DEBUG && targetEnvironment(simulator)
import HealthKit

enum SimulatorHealthSeeder
{
    private enum SeedError: Error
    {
        case healthKitUnavailable
        case writePermissionDenied
        case saveFailed
    }

    static func runIfRequested() async
    {
        guard ProcessInfo.processInfo.arguments.contains("--seed-simulator-health") else { return }

        do
        {
            let count = try await seed()
            print("[SimulatorHealthSeed] Submitted \(count) HealthKit samples")
        }
        catch
        {
            print("[SimulatorHealthSeed] Failed: \(error)")
        }
    }

    private static func seed() async throws -> Int
    {
        guard HKHealthStore.isHealthDataAvailable() else { throw SeedError.healthKitUnavailable }

        let store = HKHealthStore()
        let identifiers: [HKQuantityTypeIdentifier] =
        [
            .basalEnergyBurned, .activeEnergyBurned, .dietaryEnergyConsumed,
            .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
            .stepCount, .bodyMass
        ]
        let types = identifiers.map(HKQuantityType.init)
        let shareTypes = Set(types.map { $0 as HKSampleType })
        let readTypes = Set(types.map { $0 as HKObjectType })

        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        guard types.allSatisfy({ store.authorizationStatus(for: $0) == .sharingAuthorized }) else
        {
            throw SeedError.writePermissionDenied
        }

        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let syncVersion = Int(now.timeIntervalSince1970)
        var samples: [HKObject] = []

        func quantitySample(_ identifier: HKQuantityTypeIdentifier, value: Double, unit: HKUnit, from start: Date, to end: Date, day: Date) -> HKQuantitySample
        {
            let metadata: [String: Any] =
            [
                HKMetadataKeySyncIdentifier: "CountKcal.Simulator.\(identifier.rawValue).\(Int(day.timeIntervalSince1970))",
                HKMetadataKeySyncVersion: NSNumber(value: syncVersion)
            ]

            return HKQuantitySample(type: HKQuantityType(identifier), quantity: HKQuantity(unit: unit, doubleValue: value), start: start, end: end, metadata: metadata)
        }

        for daysAgo in (0..<37).reversed()
        {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }

            let dayNumber = 36 - daysAgo
            let end = min(now, nextDay.addingTimeInterval(-1))
            let dayFraction = daysAgo == 0 ? max(0.1, min(1, now.timeIntervalSince(day) / nextDay.timeIntervalSince(day))) : 1.0
            let mealTime = min(end, day.addingTimeInterval(12 * 60 * 60))
            let weighTime = min(end, day.addingTimeInterval(7 * 60 * 60))

            let basal = Double(1640 + (dayNumber * 37) % 180) * dayFraction
            let active = Double(350 + (dayNumber * 53) % 380) * dayFraction
            let eaten = Double(1850 + (dayNumber * 67) % 480) * dayFraction
            let protein = Double(100 + (dayNumber * 7) % 45) * dayFraction
            let carbs = Double(190 + (dayNumber * 11) % 65) * dayFraction
            let fat = Double(58 + (dayNumber * 3) % 30) * dayFraction
            let steps = Double(5500 + (dayNumber * 431) % 7500) * dayFraction
            let weight = 81.5 - Double(dayNumber) * 0.05

            samples.append(quantitySample(.basalEnergyBurned, value: basal, unit: .kilocalorie(), from: day, to: end, day: day))
            samples.append(quantitySample(.activeEnergyBurned, value: active, unit: .kilocalorie(), from: day, to: end, day: day))
            samples.append(quantitySample(.dietaryEnergyConsumed, value: eaten, unit: .kilocalorie(), from: mealTime, to: mealTime, day: day))
            samples.append(quantitySample(.dietaryProtein, value: protein, unit: .gram(), from: mealTime, to: mealTime, day: day))
            samples.append(quantitySample(.dietaryCarbohydrates, value: carbs, unit: .gram(), from: mealTime, to: mealTime, day: day))
            samples.append(quantitySample(.dietaryFatTotal, value: fat, unit: .gram(), from: mealTime, to: mealTime, day: day))
            samples.append(quantitySample(.stepCount, value: steps, unit: .count(), from: day, to: end, day: day))
            samples.append(quantitySample(.bodyMass, value: weight, unit: .gramUnit(with: .kilo), from: weighTime, to: weighTime, day: day))
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(samples)
            { saved, error in
                if let error { continuation.resume(throwing: error) }
                else if saved { continuation.resume() }
                else { continuation.resume(throwing: SeedError.saveFailed) }
            }
        }

        return samples.count
    }
}
#endif
