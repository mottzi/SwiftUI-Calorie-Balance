import SwiftUI
import WidgetKit

struct BalanceCircleGaugeMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.gauge.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGaugeComplicationView(entry: entry, mode: .midnight)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Gauge (midnight)"))
        .description(String("Shows caloric balance at midnight (gauge)"))
        .supportedFamilies([.accessoryCircular])
    }
}


#Preview(as: .accessoryCircular)
{
    BalanceCircleGaugeMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, balance: .deficit))
}
