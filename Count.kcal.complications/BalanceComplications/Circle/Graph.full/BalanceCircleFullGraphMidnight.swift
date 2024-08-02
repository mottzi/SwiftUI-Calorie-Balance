import SwiftUI
import WidgetKit

struct BalanceCircleFullGraphMidnightComplicationView : View
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
                CircleBalanceGraphWatch(mode: .midnight, rendering: renderingMode, context: .circleFull, cutout: 0.2)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
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

struct BalanceCircleFullGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.full.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleFullGraphMidnightComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #3 (midnight)"))
        .description(String("Shows caloric balance at midnight (full graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleFullGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
