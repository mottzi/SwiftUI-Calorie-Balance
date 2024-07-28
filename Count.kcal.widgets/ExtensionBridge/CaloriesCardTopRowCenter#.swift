import SwiftUI

struct CaloriesCardTopRowCenter: View 
{
    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    private var goalReached: Bool 
    {
        // loose weight goal
        if AppSettings.weightGoal == .lose
        {
            return DataViewModel.sample.balanceNow >= Int(AppSettings.balanceGoal)
        }
        // gain weight goal
        else
        {
            return DataViewModel.sample.balanceNow <= -Int(AppSettings.balanceGoal)
        }
    }
    
    var body: some View
    {
        ZStack
        {
            CircleBalanceGraph(mode: .now)
                .frame(width: 130, height: 130)

            VStack(spacing: 0)
            {
                Text("\(abs(DataViewModel.sample.balanceNow))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(DataViewModel.sample.balanceNow))))
                
                Text(DataViewModel.sample.balanceNow > 0 ? String(localized: "Deficit") : DataViewModel.sample.balanceNow == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .fontDesign(.rounded)
        
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40)
                .transaction { $0.animation = .none }
        }
    }
}
