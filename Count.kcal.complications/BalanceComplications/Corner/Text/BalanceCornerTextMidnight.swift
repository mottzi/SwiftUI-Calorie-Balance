import SwiftUI
import WidgetKit

struct BalanceCornerTextMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry

    var balanceColor: Color
    {
        var c = entry.data.balanceMidnight > 0 ? Settings.shared.burnedColor : entry.data.balanceMidnight < 0 ? Settings.shared.consumedColor : Color.white
        
        c = c.brighten(0.6)
        
        return c
    }
    
    var body: some View
    {
        switch family
        {
            case .accessoryCorner: do
            {
                Text("\(abs(entry.data.balanceMidnight))")
                    .widgetCurvesContent()
                    .widgetLabel
                    {
                        Text(entry.data.balanceMidnight > 0 ? "Deficit" : entry.data.balanceMidnight == 0 ? "Balance" : "Surplus")
                            .foregroundStyle(balanceColor)
                    }
            }
            default: EmptyView()
        }
    }
}

struct BalanceCornerTextMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.text.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerTextMidnightComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("midnight")
//        .description("")
        .description("Shows caloric balance at midnight with text.")
        .supportedFamilies([.accessoryCorner])
    }
}

#Preview(as: .accessoryCorner)
{
    BalanceCornerTextComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
