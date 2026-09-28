import SwiftUI
import WidgetKit

/// Daily energy, nutrient, and step summary.
struct Dashboard: View {

    @Binding var todayPageMode: PagerSelection
    var nutrientGoals: NutrientGoals? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            DashboardCalories(todayPageMode: $todayPageMode)
            MacroCard(goals: nutrientGoals)
            DashboardSteps()
        }
    }

}

/// Daily calorie card and the Today mode control.
private struct DashboardCalories: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(HealthInterface.self) private var day

    @Binding var todayPageMode: PagerSelection

    var body: some View {
        Card("Calories", secondaryTitle: subtitle, innerPadding: 0) {
            VStack {
                if day.isTodayPage {
                    CaloriesMidnightCard(todayPageMode: $todayPageMode)
                } else {
                    CaloriesCard()
                        .padding(16)
                }
            }
        }
        .overlay(alignment: .top) {
            if day.isTodayPage {
                HStack {
                    Circle()
                        .fill(Color("TextColor"))
                        .frame(width: 8)
                        .opacity(todayPageMode == .first ? 0.8 : 0.2)

                    Circle()
                        .fill(Color("TextColor"))
                        .frame(width: 8)
                        .opacity(todayPageMode == .second ? 0.8 : 0.2)
                }
                .offset(y: dynamicType <= .xxLarge ? 5 : 10)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            guard day.isTodayPage else { return }
            withAnimation(.snappy) {
                todayPageMode = todayPageMode == .first ? .second : .first
            }
        }
    }

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

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
                .environment(Streak())
        }
    }
}
