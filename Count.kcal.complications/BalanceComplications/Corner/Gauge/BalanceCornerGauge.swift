import SwiftUI
import WidgetKit

struct BalanceCornerGaugeComplicationView : View
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
                Text("\(entry.data.balanceNow)")
                    .widgetCurvesContent()
                    .widgetLabel
                    {
                        Gauge(
                            value: CGFloat(entry.data.balanceNow).clamped(to: range),
                            in: range,
                            label: { Text("") }
                        )
                        .tint(Gradient(colors: [Settings.shared.consumedColor, Settings.shared.burnedColor]))
                    }
            }
                
            default: Text("No support.")
        }
    }
}

struct BalanceCornerGaugeComplication: Widget
{
    var body: some WidgetConfiguration 
    {
        StaticConfiguration(kind: "Balance.corner.gauge.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerGaugeComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Balance gauge - now")
        .description("Shows current caloric balance and a gauge.")
        .supportedFamilies([.accessoryCorner])
    }
}


#Preview(as: .accessoryCorner)
{
    BalanceCornerGaugeComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

