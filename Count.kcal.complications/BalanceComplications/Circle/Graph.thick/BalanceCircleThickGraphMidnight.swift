import SwiftUI
import WidgetKit

struct BalanceCircleThickGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.thick.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleThickGraphComplicationView(entry: entry, mode: .midnight)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #2 (midnight)"))
        .description(String("Shows caloric balance at midnight (thick graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleThickGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
