import SwiftUI
import WidgetKit

/// Thick circular balance graph with amount and status for one mode.
struct BalanceCircleThickGraphComplicationView : View {

    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode
    
    var body: some View {
        switch family {
            case .accessoryCircular: do {
                CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circleThick, cutout: 0.35)
                    .widgetAccentable()
                    .environment(HealthInterface(entry.data))
                    .environmentObject(Settings.shared)
                    .overlay {
                        Image(systemName: balanceSymbol)
                            .font(.system(size: 10))
                            .widgetAccentable()
                            .offset(y: 1)
                    }
                    .overlay(alignment: .bottom) {
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

extension BalanceCircleThickGraphComplicationView {

    private var balance: Int {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var balanceSymbol: String {
        balance > 0 ? "bolt.fill" : balance < 0 ? "fork.knife" : "dot"
    }

}

/// Thick circular graph complication for the selected balance mode.
struct BalanceCircleThickGraphComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCircleThickGraphComplicationView(entry: entry, mode: Mode.graphMode)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Graph #2 (now)") : String("Graph #2 (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance (thick graph)")
                : String("Shows caloric balance at midnight (thick graph)")
        )
        .supportedFamilies([.accessoryCircular])
    }

}

extension BalanceCircleThickGraphComplication {

    private var kind: String {
        Mode.graphMode == .now ? "Balance.circle.thick.graph.now" : "Balance.circle.thick.graph.midnight"
    }

}

#Preview(as: .accessoryCircular) {
    BalanceCircleThickGraphComplication<NowComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .accessoryCircular) {
    BalanceCircleThickGraphComplication<MidnightComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
