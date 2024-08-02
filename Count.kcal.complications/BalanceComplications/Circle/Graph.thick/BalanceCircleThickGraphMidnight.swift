import SwiftUI
import WidgetKit

struct BalanceCircleThickGraphMidnightComplicationView : View
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
                CircleBalanceGraphWatch(mode: .midnight, rendering: renderingMode, context: .circleThick, cutout: 0.35)
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
                        Text("\(abs(entry.data.balanceMidnight))")
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

struct BalanceCircleThickGraphMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.thick.graph.midnight", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleThickGraphMidnightComplicationView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #2 (midnight)"))
        .description(String("Shows caloric balance at midnight (thick graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleThickGraphMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
