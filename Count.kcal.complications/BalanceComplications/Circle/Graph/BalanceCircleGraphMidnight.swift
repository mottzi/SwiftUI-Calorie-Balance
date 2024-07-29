import SwiftUI
import WidgetKit

struct BalanceCircleGraphMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
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
                CircleBalanceGraphWatch(mode: .midnight, rendering: renderingMode, context: .circle, cutout: 0.2)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
                    .overlay
                    {
                        GeometryReader
                        { geo in
                            Text("\(abs(entry.data.balanceMidnight))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .frame(width: geo.size.width - 22)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .overlay(alignment: .bottom)
                    {
                        Image(systemName: balanceSymbol)
                            .font(.system(size: 11))
                            .widgetAccentable()
                    }
            }
            default: EmptyView()
        }
    }
}

struct BalanceCircleGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGraphMidnightComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Graph #1 (midnight)")
//        .description("")
        .description("Shows caloric balance at midnight (graph)")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
