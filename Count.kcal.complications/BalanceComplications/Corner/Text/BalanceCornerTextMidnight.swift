import SwiftUI
import WidgetKit

struct BalanceCornerTextMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.text.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerTextContent(entry: entry, mode: .midnight)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Number (midnight)"))
        .description(String("Shows caloric balance at midnight with text."))
        .supportedFamilies([.accessoryCorner])
    }
}

#Preview(as: .accessoryCorner)
{
    BalanceCornerTextMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
