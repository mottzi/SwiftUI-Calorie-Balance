import SwiftUI

struct MacroCard: View
{
    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    var body: some View
    {
        Card("Nutrients")
        {
            VStack(spacing: 16)
            {
                ReachableView("Carbs", consumedValue: DataViewModel.sample.carbs, goalValue: AppSettings.carbsGoal, color: AppSettings.consumedColor, graphHeight: 10)
                
                ReachableView("Fats", consumedValue: DataViewModel.sample.fats, goalValue: AppSettings.fatsGoal, color: AppSettings.consumedColor, graphHeight: 10)
                
                ReachableView("Protein", consumedValue: DataViewModel.sample.protein, goalValue: AppSettings.proteinGoal, color: AppSettings.consumedColor, graphHeight: 10)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 2)
        }
    }
}

#Preview { PreviewPager }
