import SwiftUI
import WidgetKit

struct BalanceCircleFullGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.full.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleFullGraphComplicationView(entry: entry, mode: .midnight)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #3 (midnight)"))
        .description(String("Shows caloric balance at midnight (full graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleFullGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
