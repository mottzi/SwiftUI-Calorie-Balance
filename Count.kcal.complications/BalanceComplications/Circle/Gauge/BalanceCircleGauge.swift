import SwiftUI
import WidgetKit

struct BalanceCircleGaugeComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
    var range: ClosedRange<CGFloat> = -1.6 * CGFloat(Settings.shared.balanceGoal) ... 1.6 * CGFloat(Settings.shared.balanceGoal)
    
    var balanceColor: Color
    {
        var c = entry.data.balanceNow > 0 ? Settings.shared.burnedColor : entry.data.balanceNow < 0 ? Settings.shared.consumedColor : Color(white: 0.4)
        
        c = c.brighten(0.2)
        
        return c
    }
    
    var balanceSymbol: String
    {
        entry.data.balanceNow > 0 ? "bolt.fill" : entry.data.balanceNow < 0 ? "fork.knife" : "dot"
    }

    var body: some View
    {
        switch family
        {
            case .accessoryCircular: do
            {
                Gauge(value: CGFloat(entry.data.balanceNow).clamped(to: range), in: range)
                {
                    Image(systemName: balanceSymbol)
                }
                currentValueLabel:
                {
                    Text("\(entry.data.balanceNow)")
                        .font(.subheadline)
                }
                .gaugeStyle(CircularGaugeStyle(tint: Gradient(colors: [Settings.shared.consumedColor, Settings.shared.burnedColor])))
            }
                
            default: Text(verbatim: "No support.")
        }
    }
}

struct BalanceCircleGaugeComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.gauge.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGaugeComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Gauge (now)")
        .description("Shows current caloric balance (gauge)")
        .supportedFamilies([.accessoryCircular])
    }
}


#Preview(as: .accessoryCircular)
{
    BalanceCircleGaugeComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, balance: .deficit))
}

