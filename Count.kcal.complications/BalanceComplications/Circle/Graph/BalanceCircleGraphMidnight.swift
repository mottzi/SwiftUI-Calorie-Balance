import SwiftUI
import WidgetKit

struct BalanceCircleGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGraphComplicationView(entry: entry, mode: .midnight)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #1 (midnight)"))
        .description(String("Shows caloric balance at midnight (graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
