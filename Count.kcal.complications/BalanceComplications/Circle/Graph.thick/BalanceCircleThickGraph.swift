import SwiftUI
import WidgetKit

struct BalanceCircleThickGraphComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
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
                CircleBalanceGraphWatch(mode: .now, rendering: renderingMode, context: .circleThick, cutout: 0.35)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
                    .overlay
                    {
                        Image(systemName: balanceSymbol)
                            .font(.system(size: 10))
                            .widgetAccentable()
                            .offset(y: 1)
                    }
                    .overlay(alignment: .bottom)
                    {
                        Text("\(abs(entry.data.balanceNow))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .offset(y: -1)
                    }
            }
            default: EmptyView()
        }
    }
}

struct BalanceCircleThickGraphComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.thick.graph.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleThickGraphComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.accessoryCircular])
        .description(String("Shows current caloric balance (thick graph)"))
        .configurationDisplayName(String("Graph #2 (now)"))
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleThickGraphComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
