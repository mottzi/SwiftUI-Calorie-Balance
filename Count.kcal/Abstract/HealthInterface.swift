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

    init(_ healthData: HealthData, repository: HealthRepository? = nil, settings: Settings = .shared) {
        let day = Calendar.current.startOfDay(for: healthData.date)
        id = day
        var initial = healthData
        initial.date = day
        sample = initial
        self.repository = repository ?? .shared
        self.settings = settings
    }

    convenience init(data: HealthData) { self.init(data) }

    /// Loads the day and publishes only the latest completed request.
    func updateMetrics(animated: Bool = true, force: Bool = false) async {

        guard !Task.isCancelled else { return }
        requestID += 1
        let currentRequest = requestID
        let revision = repository.revision
        let key = SnapshotKey(
            revision: revision,
            source: settings.dataSource.rawValue,
            unit: settings.energyUnit.rawValue,
            active: settings.customCalActive,
            passive: settings.customCalPassive
        )
        // Reuse complete snapshots while browsing. Settings and explicit refreshes
        // invalidate the cache; Today expires sooner because it is still changing.
        let lifetime: TimeInterval = isTodayPage ? 15 : 60
        if !force, loadedKey == key, let synced = sample.lastDataSync,
           Date.now.timeIntervalSince(synced) < lifetime { return }
        let updated = await repository.fetchDailySnapshot(for: id, settings: settings)
        // discard a cancelled request or one superseded by a later refresh
        guard !Task.isCancelled, currentRequest == requestID, repository.revision == revision else { return }

        loadedKey = key
        if animated {
            withAnimation(.snappy) { sample = updated }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { sample = updated }
        }
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
