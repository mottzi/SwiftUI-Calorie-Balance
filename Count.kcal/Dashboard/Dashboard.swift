import SwiftUI
import WidgetKit

/// Daily energy, nutrient, and step summary.
struct Dashboard: View {

    @EnvironmentObject private var settings: Settings

    @Environment(HealthInterface.self) private var day

    @Binding var todayPageMode: TodayPageMode

    var nutrientGoals: NutrientGoals? = nil
    
    var body: some View {
        if day.sample.isUnavailable {
            ContentUnavailableView(
                "Health data unavailable",
                systemImage: "exclamationmark.icloud",
                description: Text("Pull down to try again.")
            )
        } else {
            cards
        }
    }

    private var cards: some View {
        VStack(spacing: 20) {
            ForEach(settings.dailyCards.filter { $0 != .steps || settings.showDashboardSteps }) { card in
                switch card {
                case .calories:
                    DashboardCalories(todayPageMode: $todayPageMode)
                case .nutrients:
                    MacroCard(goals: nutrientGoals)
                case .steps:
                    DashboardSteps()
                }
            }
        }
    }

}

/// Daily calorie card and the Today mode control.
private struct DashboardCalories: View {

    @Environment(HealthInterface.self) private var day

    @Binding var todayPageMode: TodayPageMode

    var body: some View {
        Card(
            "Calories",
            level: .clear,
            secondaryTitle: subtitle,
            innerPadding: 0
        ) {
            Group {
                if day.isTodayPage {
                    CaloriesMidnightCard(todayPageMode: $todayPageMode)
                } else {
                    CaloriesCard(mode: .now)
                        // Reserve the same depth without changing the face height on other days.
                        .padding(.bottom, CaloriesMidnightCard.rimDepth)
                }
            }
            .modifier(HealthLoadingPlaceholder(
                isLoading: !day.hasLoadedSnapshot,
                label: "Loading calorie data",
                showsProgressIndicator: true
            ))
        }
        .overlay(alignment: .topTrailing) {
            DayChoiceButton()
                .disabled(!day.hasLoadedSnapshot)
                .padding(.trailing, 16)
                .offset(y: -12)
        }
    }

}

extension DashboardCalories {

    private var subtitle: String {
        guard day.hasLoadedSnapshot else { return "" }
        if day.isTodayPage {
            if todayPageMode.selection == .second {
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
                graphHeight: 10,
                isLoading: !day.hasLoadedSnapshot
            )
            .padding(.horizontal, 11)
            .padding(.bottom, 6)
            .modifier(HealthLoadingPlaceholder(isLoading: !day.hasLoadedSnapshot, label: "Loading step data"))
        }
    }

}

#Preview { PreviewPager }
