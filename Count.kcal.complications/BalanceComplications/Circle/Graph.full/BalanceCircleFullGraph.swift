import SwiftUI
import WidgetKit

/// Full circular balance graph with a status symbol for one mode.
struct BalanceCircleFullGraphComplicationView : View
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
                CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circleFull, cutout: 0.2)
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

struct BalanceCircleFullGraphComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.circle.full.graph.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCircleFullGraphComplicationView(entry: entry, mode: .now)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String("Graph #3 (now)"))
        .description(String("Shows current caloric balance (full graph)"))
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleFullGraphComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
