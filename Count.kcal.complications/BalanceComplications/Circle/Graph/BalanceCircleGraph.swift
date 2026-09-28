import SwiftUI
import WidgetKit

/// Circular balance graph with an amount and status symbol for one mode.
struct BalanceCircleGraphComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode
    
    private var balance: Int
    {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var balanceSymbol: String
    {
        balance > 0 ? "bolt.fill" : balance < 0 ? "fork.knife" : "dot"
    }

    var body: some View
    {
        switch family
        {
            case .accessoryCircular: do
            {
                CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circle, cutout: 0.2)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
                    .overlay
                    {
                        GeometryReader
                        { geo in
                            Text("\(abs(balance))")
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

struct BalanceCircleGraphComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.graph.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleGraphComplicationView(entry: entry, mode: .now)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #1 (now)"))
        .description(String("Shows current caloric balance (graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleGraphComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
