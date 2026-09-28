import SwiftUI
import WidgetKit

/// Thick circular balance graph with amount and status for one mode.
struct BalanceCircleThickGraphComplicationView : View
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
                CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circleThick, cutout: 0.35)
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
                        Text("\(abs(balance))")
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
            BalanceCircleThickGraphComplicationView(entry: entry, mode: .now)
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
