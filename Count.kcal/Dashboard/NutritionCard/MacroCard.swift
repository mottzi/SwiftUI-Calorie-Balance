import SwiftUI

struct MacroCard: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    var goals: NutrientGoals? = nil

    var body: some View {
        Card("Nutrients") {
            VStack(spacing: 16) {
                ForEach(AppSettings.macros) { macro in
                    ReachableView(
                        macro.title,
                        consumedValue: macro.consumed(in: DataViewModel.sample),
                        goalValue: goal(for: macro),
                        color: AppSettings.consumedColor,
                        graphHeight: 10,
                        isLoading: isLoading
                    )
                }
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 8)
            .modifier(HealthLoadingPlaceholder(
                isLoading: isLoading,
                label: "Loading nutrient data"
            ))
        }
    }

    private func goal(for macro: MacroNutrient) -> Int {
        guard let goals else { return macro.goal(in: AppSettings) }
        switch macro {
        case .carbs: return goals.carbs
        case .fats: return goals.fats
        case .protein: return goals.protein
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
