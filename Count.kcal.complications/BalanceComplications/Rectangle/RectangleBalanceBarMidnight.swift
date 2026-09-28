import SwiftUI
import WidgetKit

struct RectangleBalanceBarMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.bar.midnight", provider: HealthDataTimelineProvider())
        { entry in
            RectangleBalanceBarComplicationView(entry: entry, mode: .midnight)
                .containerBackground(Color(red: 30/255, green: 30/255, blue: 30/255), for: .widget)

        }
        .configurationDisplayName(String("Bar (midnight)"))
        .description(String("Shows caloric balance at midnight."))
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular)
{
    RectangleBalanceBarMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
