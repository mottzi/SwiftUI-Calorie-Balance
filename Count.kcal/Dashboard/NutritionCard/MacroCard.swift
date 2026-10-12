import SwiftUI

struct MacroCard: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    var goals: NutrientGoals? = nil

    var body: some View {
        Card("Nutrients") {
            VStack(spacing: 16) {
                ReachableView(
                    "Carbs",
                    consumedValue: DataViewModel.sample.carbs,
                    goalValue: goals?.carbs ?? AppSettings.carbsGoal,
                    color: AppSettings.consumedColor,
                    graphHeight: 10,
                    isLoading: isLoading
                )
                
                ReachableView(
                    "Fats",
                    consumedValue: DataViewModel.sample.fats,
                    goalValue: goals?.fats ?? AppSettings.fatsGoal,
                    color: AppSettings.consumedColor,
                    graphHeight: 10,
                    isLoading: isLoading
                )
                
                ReachableView(
                    "Protein",
                    consumedValue: DataViewModel.sample.protein,
                    goalValue: goals?.protein ?? AppSettings.proteinGoal,
                    color: AppSettings.consumedColor,
                    graphHeight: 10,
                    isLoading: isLoading
                )
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 2)
            .modifier(HealthLoadingPlaceholder(
                isLoading: isLoading,
                label: "Loading nutrient data"
            ))
        }
    }

    private var isLoading: Bool {
        !DataViewModel.hasLoadedSnapshot || (goals == nil && AppSettings.calorieDataState == .loading)
    }

}

struct NutrientGoals {

    let carbs: Int
    let fats: Int
    let protein: Int

}

#Preview { PreviewPager }
