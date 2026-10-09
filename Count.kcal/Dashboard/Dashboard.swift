import SwiftUI
import WidgetKit

/// Daily energy, nutrient, and step summary.
struct Dashboard: View {

    @Binding var todayPageMode: PagerSelection
    var calorieCardPressTrigger: Int = 0

    var nutrientGoals: NutrientGoals? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            DashboardCalories(
                todayPageMode: $todayPageMode,
                calorieCardPressTrigger: calorieCardPressTrigger
            )
            MacroCard(goals: nutrientGoals)
            DashboardSteps()
        }
    }

}

/// Daily calorie card and the Today mode control.
private struct DashboardCalories: View {

    @Environment(HealthInterface.self) private var day

    @Binding var todayPageMode: PagerSelection
    let calorieCardPressTrigger: Int

    var body: some View {
        Card(
            "Calories",
            level: .clear,
            secondaryTitle: subtitle,
            innerPadding: 0
        ) {
            if day.isTodayPage {
                CaloriesMidnightCard(
                    todayPageMode: $todayPageMode,
                    pressTrigger: calorieCardPressTrigger
                )
            } else {
                CaloriesCard(mode: .now)
                    // Reserve the same depth without changing the face height on other days.
                    .padding(.bottom, CaloriesMidnightCard.rimPadding)
            }
        }
        .overlay(alignment: .topTrailing) {
            DayChoiceButton()
                .padding(.trailing, 16)
                .offset(y: -12)
        }
    }

}

extension DashboardCalories {

    private var subtitle: String {
        if day.isTodayPage {
            if todayPageMode == .second {
                return String(localized: "Midnight")
            } else {
                return String(localized: "Now, \((day.sample.lastDataSync ?? .now).shortTime)")
            }
        }
        
        return String("")
    }

}

/// Step progress for the current day's health snapshot.
private struct DashboardSteps: View {

    @EnvironmentObject private var settings: Settings

    @Environment(HealthInterface.self) private var day

    var body: some View {
        Card("Steps") {
            ReachableView(
                "Steps",
                context: .app,
                consumedValue: day.sample.steps,
                goalValue: settings.stepsGoal,
                unit: "",
                color: settings.burnedColor,
                graphHeight: 10
            )
            .padding(.horizontal, 11)
            .padding(.bottom, 6)
        }
    }

}

#Preview { PreviewPager }
