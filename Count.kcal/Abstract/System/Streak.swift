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
        var streak = 0
        var date = Date.now.yesterday

        while streak < 200 {
            // stop if another count replaced this one during the HealthKit query
            guard !Task.isCancelled, currentRequest == requestID else { return }
            let data = await repository.fetchDailySnapshot(for: date, settings: settings)
            guard !Task.isCancelled, currentRequest == requestID else { return }
            guard data.consumed > 0 else { break }
            guard isLossGoal ? data.balanceNow >= goal : data.balanceNow <= -goal else { break }
            streak += 1
            date = date.yesterday
        }

        guard !Task.isCancelled, currentRequest == requestID else { return }
        streaks = streak
    }

    /// Shows or hides the streak value.
    func toggleStreaksView() { withAnimation(.snappy) { showStreaksView.toggle() } }

}
