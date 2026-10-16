import SwiftUI

/// Production card layouts with the smallest text omitted at miniature scale.
struct DashboardPreviewCard: View {
    @EnvironmentObject private var settings: Settings

    let card: DailyDashboardCard
    let macros: [MacroNutrient]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch card {
            case .calories:
                CaloriesMidnightCard(todayPageMode: .constant(TodayPageMode()), showsDetails: false)
                    .redacted(reason: .placeholder)
            case .nutrients:
                VStack(spacing: 16) {
                    ForEach(macros) { macro in
                        ReachableView(
                            macro.title,
                            consumedValue: macro == .protein ? 85 : macro == .carbs ? 70 : 60,
                            goalValue: 120,
                            color: settings.consumedColor,
                            graphHeight: 10,
                            showsHeader: false
                        )
                        .geometryGroup()
                    }
                }
                .padding(.horizontal, 27)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(settings.CardBackground, in: .rect(cornerRadius: 10))
            case .steps:
                ReachableView(
                    "Steps",
                    consumedValue: 6_240,
                    goalValue: 10_000,
                    unit: "",
                    color: settings.burnedColor,
                    graphHeight: 10,
                    showsHeader: false
                )
                .padding(.horizontal, 27)
                .padding(.top, 16)
                .padding(.bottom, 22)
                .background(settings.CardBackground, in: .rect(cornerRadius: 10))
            }
        }
        .fontDesign(.rounded)
    }
}
