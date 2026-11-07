import SwiftUI
import Observation

@MainActor
@Observable
/// Consecutive completed goal days and their chart membership.
final class Streak {

    var showStreaksView = true
    private var result: Result?
    private var excludedDays: Set<String> = []

    @ObservationIgnored private let repository: HealthRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0

    init(repository: HealthRepository? = nil, settings: Settings? = nil) {
        self.repository = repository ?? .shared
        self.settings = settings ?? .shared
    }

    /// Recounts completed goal days from yesterday until the first break.
    func updateStreaks() async {

        guard !Task.isCancelled else { return }
        requestID += 1
        let currentRequest = requestID
        let key = inputKey
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: key.today)!
        let history = try? await repository.fetchStreakEnergy(
            endingOn: yesterday,
            days: 200,
            source: key.source,
            energyUnit: key.energyUnit,
            customActive: key.customActive,
            customPassive: key.customPassive
        )
        // A cancelled refresh must leave the last completed count visible.
        guard !Task.isCancelled else { return }
        guard let days = history else {
            if currentRequest == requestID { result = nil }
            return
        }
        guard currentRequest == requestID, inputKey == key else { return }
        let count = days.prefix { qualifies($0, for: key) }.count
        result = Result(key: key, count: count)
    }

    /// The count and membership are available only for their original measurements and goals.
    var hasLoadedCount: Bool { result?.key == inputKey }

    var streaks: Int {

        guard hasLoadedCount, let result else { return 0 }
        let calendar = Calendar.current
        for offset in 0..<result.count {
            let day = calendar.date(byAdding: .day, value: -offset - 1, to: result.key.today)!
            if excludedDays.contains(DayKey.make(day)) { return offset }
        }
        return result.count
    }

    /// Applies saved exclusions to the count and membership without reloading measurements.
    func updateDayChoices(_ choices: [String: DayChoice]) {
        excludedDays = Set(choices.filter { $0.value == .excluded }.keys)
    }

    /// Completed days in the current streak, including saved exclusions.
    var currentRange: Range<Date>? {
        guard hasLoadedCount, let result else { return nil }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -streaks, to: result.key.today)!
        return start..<result.key.today
    }

    /// Includes only completed days that contribute to the count.
    func contains(_ date: Date) -> Bool {
        currentRange?.contains(Calendar.current.startOfDay(for: date)) ?? false
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
