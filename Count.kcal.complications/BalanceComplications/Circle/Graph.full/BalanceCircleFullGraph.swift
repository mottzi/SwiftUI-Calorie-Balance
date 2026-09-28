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

/// Full circular graph complication for the selected balance mode.
struct BalanceCircleFullGraphComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCircleFullGraphComplicationView(entry: entry, mode: Mode.graphMode)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Graph #3 (now)") : String("Graph #3 (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance (full graph)")
                : String("Shows caloric balance at midnight (full graph)")
        )
        .supportedFamilies([.accessoryCircular])
    }

    private var kind: String {
        Mode.graphMode == .now ? "Balance.circle.full.graph.now" : "Balance.circle.full.graph.midnight"
    }

}

#Preview(as: .accessoryCircular)
{
    BalanceCircleFullGraphComplication<NowComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .accessoryCircular)
{
    BalanceCircleFullGraphComplication<MidnightComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
