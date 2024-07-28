import SwiftUI
import Observation

@Observable class Streak
{
    var streaks: Int = 0
    var showStreaksView: Bool = true
    
    private func updateStreaks(to newStreaks: Int) { streaks = newStreaks }
    
    func toggleStreaksView() { withAnimation(.snappy) { showStreaksView.toggle() } }
    
    func updateStreaks() async
    {
        var streak = 0
        var date = Date.now.yesterday
        var dataInterface: HealthInterface
        
        while true
        {
            if streak > 200 { break }
            
            dataInterface = HealthInterface(HealthData.empty(for: date))
            await dataInterface.updateMetrics()
            
            if isGoalReached(data: dataInterface.sample)
            {
                streak += 1
                date = date.yesterday
            }
            else
            {
                break
            }
        }
        
        self.updateStreaks(to: streak)
    }
    
    private func isGoalReached(data: HealthData) -> Bool
    {
        if data.consumed <= 0 { return false }
        
        if Settings.shared.weightGoal == .lose
        {
            return data.balanceMidnight >= Int(Settings.shared.balanceGoal)
        }
        else
        {
            return data.balanceMidnight <= -Int(Settings.shared.balanceGoal)
        }
    }
}
