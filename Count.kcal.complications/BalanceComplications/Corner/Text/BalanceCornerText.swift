import SwiftUI
import WidgetKit

struct BalanceCornerTextComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry

    var balanceColor: Color
    {
        var c = entry.data.balanceNow > 0 ? Settings.shared.burnedColor : entry.data.balanceNow < 0 ? Settings.shared.consumedColor : Color.white
        
        c = c.brighten(0.6)
        
        return c
    }
    
    var body: some View
    {
        switch family
        {
            case .accessoryCorner: do
            {
                Text("\(abs(entry.data.balanceNow))")
                    .widgetCurvesContent()
                    .widgetLabel
                    {
                        Text(entry.data.balanceNow > 0 ? "Deficit" : entry.data.balanceNow == 0 ? "Balance" : "Surplus")
                            .foregroundStyle(balanceColor)
                    }
            }
                
            default: EmptyView()
        }
    }
}

struct BalanceCornerTextComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.text.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerTextComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("now")
//        .description("")
        .description("Shows current caloric balance with text.")
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

