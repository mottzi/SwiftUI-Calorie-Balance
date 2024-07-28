import WidgetKit
import SwiftUI

struct NutritionWidget: Widget
{
    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: "BarNutritionBalanceGraphWidget",
            provider: ToggleWidgetProvider())
        { entry in
            NutritionWidgetNow(entry: entry)
                .containerRelativeFrame([.horizontal, .vertical])
                .containerBackground(Color("BackGroundColor"), for: .widget)
                .environmentObject(AppSettings)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows your macronutrients.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NutritionWidgetNow: View
{
    @State private var AppSettings = Settings.shared
    
    @Environment(\.colorScheme) var scheme: ColorScheme
    @Environment(\.widgetFamily) var family: WidgetFamily
    var entry: ToggleWidgetProvider.Entry
    
    var body: some View
    {
        switch family
        {
            case .systemSmall, .systemMedium:
            ZStack(alignment: .topLeading)
            {
//                timeReloadButton
                
                VStack(spacing: 14)
                {
                    ReachableView(family == .systemMedium ? "Carbs" : "C", context: .widget(family), consumedValue: entry.data.carbs, goalValue: AppSettings.carbsGoal, color: AppSettings.consumedColor, graphHeight: 10)
                    
                    ReachableView(family == .systemMedium ? "Fats" : "F", context: .widget(family), consumedValue: entry.data.fats, goalValue: AppSettings.fatsGoal, color: AppSettings.consumedColor, graphHeight: 10)
                    
                    ReachableView(family == .systemMedium ? "Protein" : "P", context: .widget(family), consumedValue: entry.data.protein, goalValue: AppSettings.proteinGoal, color: AppSettings.consumedColor, graphHeight: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(family == .systemMedium ? 20 : 5)
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .padding(.bottom, family == .systemMedium ? 2 : -2)
            }
            
        default:
            Text(verbatim: "Widget size not supported")
        }
    }
    
    var timeReloadButton: some View
    {
        Button(intent: TestAppIntent())
        {
            ZStack(alignment: .topLeading)
            {
                Color.clear
                    .frame(width: 80, height: 70)
                
                Text(verbatim: "\(entry.date.shortTime)")
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .font(.caption)
                    .fontWeight(.thin)
                    .padding(.leading, 12)
                    .padding(.trailing, 9)
                    .padding(.top, 2)
                    .background
                    {
                        if scheme == .dark
                        {
                            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 20, topTrailingRadius: 0, style: .continuous)
                                .fill(Color("BackGroundColor").gradient)
                        }
                    }
                    .opacity(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview(as: .systemSmall)
{
    NutritionWidget()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
