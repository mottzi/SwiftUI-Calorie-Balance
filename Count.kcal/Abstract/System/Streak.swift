import SwiftUI
import Observation

@Observable
/// Consecutive past days that meet the selected energy balance goal.
class Streak {
    var streaks: Int = 0
    var showStreaksView: Bool = true
    
    /// Recounts goal days from yesterday until a day fails or the limit is reached.
    func updateStreaks() async {
        var streak = 0
        var date = Date.now.yesterday
        var dataInterface: HealthInterface
        
        while true {
            if streak > 200 { break }
            
            dataInterface = HealthInterface(HealthData.empty(for: date))
            await dataInterface.updateMetrics()
            
            if isGoalReached(data: dataInterface.sample) {
                streak += 1
                date = date.yesterday
            } else {
                break
            }
        }
        
        self.updateStreaks(to: streak)
    }

    func toggleStreaksView() { withAnimation(.snappy) { showStreaksView.toggle() } }
}

extension Streak {

    private func isGoalReached(data: HealthData) -> Bool {
        if data.consumed <= 0 { return false }
        
        if Settings.shared.weightGoal == .lose {
            return data.balanceMidnight >= Int(Settings.shared.balanceGoal)
        } else {
            return data.balanceMidnight <= -Int(Settings.shared.balanceGoal)
        }
    }

    private func updateStreaks(to newStreaks: Int) { streaks = newStreaks }

}
