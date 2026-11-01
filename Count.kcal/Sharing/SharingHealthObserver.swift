import HealthKit

@MainActor
/// HealthKit observer queries that report successful updates to their caller.
final class SharingHealthObserver {

    /// HealthKit store that runs the observer queries.
    private let store = HKHealthStore()

    /// Active queries that stop() can cancel.
    private var queries: [HKObserverQuery] = []

    /// Starts calorie observer queries and requests hourly background delivery.
    func start(onChange: @escaping @MainActor () async -> Void) {

        guard queries.isEmpty, HKHealthStore.isHealthDataAvailable() else { return }
        for identifier in [HKQuantityTypeIdentifier.activeEnergyBurned, .basalEnergyBurned, .dietaryEnergyConsumed] {
            let type = HKQuantityType(identifier)
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                Task { @MainActor in
                    if error == nil { await onChange() }
                    completion()
                }
            }
            queries.append(query)
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// Stops active queries and clears their references.
    func stop() {
        queries.forEach(store.stop)
        queries.removeAll()
    }

}
