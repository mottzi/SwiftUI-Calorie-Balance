import SwiftUI
import Observation

@MainActor
@Observable
/// Consecutive past days that meet the selected energy balance goal.
final class Streak {

    var streaks: Int = 0
    var showStreaksView: Bool = true

    @ObservationIgnored private let repository: HKRepository
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private var requestID = 0

    init(repository: HKRepository = .shared, settings: Settings = .shared) {
        self.repository = repository
        self.settings = settings
    }
    
    /// Recounts goal days from yesterday until a day fails or the limit is reached.
    func updateStreaks() async {

        requestID += 1
        let currentRequest = requestID
        let goal = settings.balanceGoal
        let isLossGoal = settings.weightGoal == .lose
        let source = settings.dataSource
        let energyUnit = settings.energyUnit
        let customActive = settings.customCalActive
        let customPassive = settings.customCalPassive
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        var streak = 0

        let days = await repository.fetchStreakEnergy(
            endingOn: yesterday,
            days: 200,
            source: source,
            energyUnit: energyUnit,
            customActive: customActive,
            customPassive: customPassive
        )
        guard !Task.isCancelled, currentRequest == requestID else { return }
        for day in days {
            guard day.consumed > 0, day.meetsGoal(goal, isLoss: isLossGoal) else { break }
            streak += 1
        }

        streaks = streak
    }

}

extension Streak {

    /// Shows or hides the streak value.
    func toggleStreaksView() { withAnimation(.snappy) { showStreaksView.toggle() } }

}
