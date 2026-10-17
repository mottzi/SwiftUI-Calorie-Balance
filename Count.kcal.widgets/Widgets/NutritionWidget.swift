import WidgetKit
import SwiftUI

/// Carbohydrate, fat, and protein goal progress for small and medium widgets.
struct NutritionWidget: Widget {

    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "BarNutritionBalanceGraphWidget",
            provider: HealthDataTimelineProvider()
        ) { entry in
            NutritionWidgetNow(entry: entry)
                .containerRelativeFrame([.horizontal, .vertical])
                .sampleHealthDataIndicator(entry)
                .healthSnapshotAvailability(isUnavailable: entry.data.isUnavailable)
                .containerBackground(Color("BackGroundColorBlack"), for: .widget)
                .environmentObject(AppSettings)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows your macronutrients.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

}

/// Nutrient progress for small, medium, and combined large widgets.
struct NutritionWidgetNow: View {

    @Environment(\.widgetFamily) var family: WidgetFamily

    @EnvironmentObject private var AppSettings: Settings
    
    var entry: HealthDataTimelineProvider.Entry
    
    /// Shows nutrient progress with short labels in the small widget.
    var body: some View {
        switch family {
            case .systemSmall, .systemMedium:
                nutrientRows
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(family == .systemMedium ? 20 : 5)
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
                    .padding(.bottom, family == .systemMedium ? 2 : -2)

            case .systemLarge:
                // The combined dashboard owns the common inset for all its bars.
                nutrientRows
            
            default:
                Text(verbatim: "Widget size not supported")
        }
    }

    private func goal(for macro: MacroNutrient) -> Int {
        switch macro {
            case .carbs: entry.policy.carbsGoal
            case .fats: entry.policy.fatsGoal
            case .protein: entry.policy.proteinGoal
        }
    }

    private var nutrientRows: some View {
        VStack(spacing: 14) {
            ForEach(AppSettings.macros) { macro in
                ReachableView(
                    family == .systemSmall ? macro.shortTitle : macro.title,
                    context: .widget(family),
                    consumedValue: macro.consumed(in: entry.data),
                    goalValue: goal(for: macro),
                    color: AppSettings.consumedColor,
                    graphHeight: 10
                )
            }
        }
    }
    
}

#Preview(as: .systemSmall) {
    NutritionWidget()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
