import SwiftUI
import Observation

@MainActor
@Observable
/// Health metrics for one calendar day.
final class HealthInterface: Identifiable, Hashable {

    /// The fixed start of the day used by lists and equality.
    @ObservationIgnored nonisolated let id: Date

    /// The last complete health snapshot published for this day.
    private(set) var sample: HealthData

    @ObservationIgnored private let repository: HealthRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0
    @ObservationIgnored private var loadedKey: SnapshotKey?
    @ObservationIgnored private var pendingKey: SnapshotKey?
    @ObservationIgnored private var pendingLoad: Task<Void, Never>?

    init(_ healthData: HealthData, repository: HealthRepository? = nil, settings: Settings? = nil) {
        let day = Calendar.current.startOfDay(for: healthData.date)
        id = day
        var initial = healthData
        initial.date = day
        sample = initial
        self.repository = repository ?? .shared
        self.settings = settings ?? .shared
    }

    convenience init(data: HealthData) { self.init(data) }

    /// Shares a day load across callers, including callers cancelled by paging.
    func updateMetrics(animated: Bool = true, force: Bool = false) async {

        guard !Task.isCancelled else { return }
        let key = snapshotKey
        if pendingKey == key, let pendingLoad {
            await pendingLoad.value
            return
        }
        let lifetime: TimeInterval = isTodayPage ? 15 : 60
        if !force, loadedKey == key, let synced = sample.lastDataSync,
           Date.now.timeIntervalSince(synced) < lifetime { return }

        pendingLoad?.cancel()
        requestID += 1
        let currentRequest = requestID
        pendingKey = key
        // The day owns this finite load. A cancelled view task must not discard
        // measurements that another chart or the next swipe can still use.
        let load = Task { @MainActor in
            let updated = await repository.fetchDailySnapshot(for: id, settings: settings)
            guard currentRequest == requestID else { return }
            pendingLoad = nil
            pendingKey = nil
            guard !Task.isCancelled, snapshotKey == key else { return }

            loadedKey = key
            if animated, sample.lastDataSync != nil {
                withAnimation(.snappy) { sample = updated }
            } else {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { sample = updated }
            }
        }
        pendingLoad = load
        await load.value
    }

    private var snapshotKey: SnapshotKey {
        SnapshotKey(
            revision: repository.revision,
            source: settings.dataSource.rawValue,
            unit: settings.energyUnit.rawValue,
            active: settings.customCalActive,
            passive: settings.customCalPassive
        )
    }

    private struct SnapshotKey: Equatable {
        let revision: String
        let source: Int
        let unit: String
        let active: Int
        let passive: Int
    }

    /// Compares fixed calendar-day identities.
    nonisolated static func == (lhs: HealthInterface, rhs: HealthInterface) -> Bool { lhs.id == rhs.id }

    /// Hashes the same fixed day used by equality.
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

}

extension HealthInterface {

    /// Tells views whether this model is the current calendar day.
    var isTodayPage: Bool { id.isToday }

    /// Fills the visible day with sample values for development controls.
    func randomizeHealthData() {

        pendingLoad?.cancel()
        pendingLoad = nil
        pendingKey = nil
        requestID += 1
        var updated = sample
        updated.burnedActive = Int.random(in: 100...1000)
        updated.burnedPassive = Int.random(in: 200...2300)
        updated.burnedPassive7 = Int.random(in: 1800...2500)
        updated.burnedActive7 = Int.random(in: 200...1000)
        updated.consumed = Int.random(in: 400...3600)
        updated.protein = Int.random(in: 70...200)
        updated.carbs = Int.random(in: 180...300)
        updated.fats = Int.random(in: 50...80)
        updated.steps = Int.random(in: 0...30000)
        sample = updated
    }

}
