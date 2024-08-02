import SwiftUI
import WidgetKit

struct BalanceCornerGaugeMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry

    var range: ClosedRange<CGFloat> = -1.6 * CGFloat(Settings.shared.balanceGoal) ... 1.6 * CGFloat(Settings.shared.balanceGoal)
    
    var body: some View
    {
        switch family
        {
            case .accessoryCorner: do
            {
                Text("\(entry.data.balanceMidnight)")
                    .widgetCurvesContent()
                    .widgetLabel
                    {
                        Gauge(value: CGFloat(entry.data.balanceMidnight).clamped(to: range), in: range, label: { Text(verbatim: "") } )
                            .tint(Gradient(colors: [Settings.shared.consumedColor, Settings.shared.burnedColor]))
                    }
            }
                
            default: EmptyView()
        }
    }
}

struct BalanceCornerGaugeMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.corner.gauge.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerGaugeMidnightComplicationView(entry: entry)
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

