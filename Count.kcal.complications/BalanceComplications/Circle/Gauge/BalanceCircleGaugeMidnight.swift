import SwiftUI
import WidgetKit

struct BalanceCircleGaugeMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
    var range: ClosedRange<CGFloat> = -1.6 * CGFloat(Settings.shared.balanceGoal) ... 1.6 * CGFloat(Settings.shared.balanceGoal)
    
    var balanceColor: Color
    {
        var c = entry.data.balanceMidnight > 0 ? Settings.shared.burnedColor : entry.data.balanceMidnight < 0 ? Settings.shared.consumedColor : Color(white: 0.4)
        
        c = c.brighten(0.2)
        
        return c
    }
    
    var balanceSymbol: String
    {
        entry.data.balanceMidnight > 0 ? "bolt.fill" : entry.data.balanceMidnight < 0 ? "fork.knife" : "dot"
    }

    var body: some View
    {
        switch family
        {
            case .accessoryCircular: do
            {
                Gauge(
                    value: CGFloat(entry.data.balanceMidnight).clamped(to: range),
                    in: range)
                {
                    Image(systemName: balanceSymbol)
                }
                currentValueLabel:
                {
                    Text("\(entry.data.balanceMidnight)")
                        .font(.subheadline)
                }
                .gaugeStyle(CircularGaugeStyle(tint: Gradient(colors: [Settings.shared.consumedColor, Settings.shared.burnedColor])))
            }
                
            default: Text(verbatim: "No support.")
        }
    }
}

struct BalanceCircleGaugeMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.gauge.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGaugeMidnightComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Gauge (midnight)")
//        .description("")
        .description("Shows caloric balance at midnight (gauge)")
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

