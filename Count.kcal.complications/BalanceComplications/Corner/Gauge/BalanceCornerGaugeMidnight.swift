import SwiftUI
import WidgetKit

struct BalanceCornerGaugeMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.corner.gauge.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerGaugeContent(entry: entry, mode: .midnight)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Gauge (midnight)"))
        .description(String("Shows caloric balance at midnight (gauge)"))
        .supportedFamilies([.accessoryCorner])
    }
}


#Preview(as: .accessoryCorner)
{
    BalanceCornerGaugeMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
