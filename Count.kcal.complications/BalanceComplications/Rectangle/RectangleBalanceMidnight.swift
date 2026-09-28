import SwiftUI
import WidgetKit

struct RectangleBalanceMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.midnight", provider: HealthDataTimelineProvider())
        { entry in
            let c = entry.data.balanceMidnight >= 0 ? Settings.shared.burnedColor : Settings.shared.consumedColor
        
            RectangleBalanceComplicationView(entry: entry, mode: .midnight)
                .containerBackground(c.brighten(0.1).gradient, for: .widget)
        }
        .configurationDisplayName(String("Circle (midnight)"))
        .description(String("Shows caloric balance at midnight."))
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular)
{
    RectangleBalanceMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
