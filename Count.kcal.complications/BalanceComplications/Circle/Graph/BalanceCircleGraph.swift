import SwiftUI
import WidgetKit

/// Circular balance graph with an amount and status symbol for one mode.
struct BalanceCircleGraphComplicationView : View {

    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode
    
    var body: some View {
        switch family {
            case .accessoryCircular: do {
                CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circle, cutout: 0.2)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
                    .overlay {
                        GeometryReader { geo in
                            Text("\(abs(balance))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .frame(width: geo.size.width - 22)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Image(systemName: balanceSymbol)
                            .font(.system(size: 11))
                            .widgetAccentable()
                    }
            }
            default: EmptyView()
        }
    }

}

extension BalanceCircleGraphComplicationView {

    private var balance: Int {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var balanceSymbol: String {
        balance > 0 ? "bolt.fill" : balance < 0 ? "fork.knife" : "dot"
    }

}

/// Circular graph complication for the selected balance mode.
struct BalanceCircleGraphComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCircleGraphComplicationView(entry: entry, mode: Mode.graphMode)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
                .healthSnapshotAvailability(isUnavailable: entry.data.isUnavailable)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Graph #1 (now)") : String("Graph #1 (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance (graph)")
                : String("Shows caloric balance at midnight (graph)")
        )
        .supportedFamilies([.accessoryCircular])
    }

}

extension BalanceCircleGraphComplication {

    private var kind: String {
        Mode.graphMode == .now ? "Balance.circle.graph.now" : "Balance.circle.graph.midnight"
    }

}

#Preview(as: .accessoryCircular) {
    BalanceCircleGraphComplication<NowComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .accessoryCircular) {
    BalanceCircleGraphComplication<MidnightComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
