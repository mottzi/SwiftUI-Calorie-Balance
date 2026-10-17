import SwiftUI
import Observation

@MainActor
@Observable
/// Consecutive goal days, with a count of completed days and membership for the chart.
final class Streak {

    var showStreaksView = true
    private var result: Result?

    @ObservationIgnored private let repository: HealthRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0

    init(repository: HealthRepository? = nil, settings: Settings? = nil) {
        self.repository = repository ?? .shared
        self.settings = settings ?? .shared
    }

    /// Recounts completed days and includes Today in chart membership if its projected balance meets the goal.
    func updateStreaks() async {

        requestID += 1
        let currentRequest = requestID
        let key = inputKey
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: key.today)!
        async let todaySnapshot = repository.fetchDailySnapshot(for: key.today, settings: settings)
        async let history = repository.fetchStreakEnergy(
            endingOn: yesterday,
            days: 200,
            source: key.source,
            energyUnit: key.energyUnit,
            customActive: key.customActive,
            customPassive: key.customPassive
        )
        guard let (today, days) = try? await (todaySnapshot, history) else {
            if currentRequest == requestID { result = nil }
            return
        }
        guard !Task.isCancelled, currentRequest == requestID, inputKey == key else { return }
        let count = days.prefix { qualifies($0, for: key) }.count
        let includesToday = !today.isUnavailable && qualifies(today.midnight, for: key)
        let start = calendar.date(byAdding: .day, value: -count, to: key.today)!
        let end = calendar.date(byAdding: .day, value: includesToday ? 1 : 0, to: key.today)!
        result = Result(key: key, count: count, days: start..<end)
    }

    /// The count and membership are available only for their original measurements and goals.
    var hasLoadedCount: Bool { result?.key == inputKey }

    var streaks: Int { hasLoadedCount ? result?.count ?? 0 : 0 }

    /// Includes qualifying Today without adding it to the completed-day count.
    func contains(_ date: Date) -> Bool {
        hasLoadedCount && result?.days.contains(Calendar.current.startOfDay(for: date)) == true
    }

    /// Discards the result and prevents a pending recount from publishing it again.
    func reset() {
        requestID += 1
        result = nil
    }

}

extension Streak {

    /// Shows or hides the streak value.
    func toggleStreaksView() { withAnimation(.snappy) { showStreaksView.toggle() } }

}

extension Streak {

    private var inputKey: InputKey {
        InputKey(
            revision: repository.revision,
            today: Calendar.current.startOfDay(for: .now),
            goal: settings.balanceGoal,
            isLoss: settings.weightGoal == .lose,
            source: settings.dataSource,
            energyUnit: settings.energyUnit,
            customActive: settings.customCalActive,
            customPassive: settings.customCalPassive
        )
    }

    private func qualifies(_ energy: EnergyBalance, for key: InputKey) -> Bool {
        energy.consumed > 0 && energy.meetsGoal(key.goal, isLoss: key.isLoss)
    }

    private struct Result: Equatable {
        let key: InputKey
        let count: Int
        let days: Range<Date>
    }

    private struct InputKey: Equatable {
        let revision: String
        let today: Date
        let goal: Int
        let isLoss: Bool
        let source: Settings.DataSources
        let energyUnit: Settings.EnergyUnit
        let customActive: Int
        let customPassive: Int
    }

}
