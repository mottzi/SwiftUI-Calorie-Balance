import SwiftUI
import WidgetKit

/// Circular gauge for the selected calorie balance mode.
struct BalanceCircleGaugeComplicationView : View {

    @Environment(\.widgetFamily) var family

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode
    
    var range: ClosedRange<CGFloat> {
        let goal = max(1, CGFloat(entry.policy.balanceGoal))
        return -1.6 * goal ... 1.6 * goal
    }
    
    var body: some View {
        switch family {
            case .accessoryCircular: do {
                Gauge(value: CGFloat(balance).clamped(to: range), in: range) {
                    Image(systemName: balanceSymbol)
                }
                currentValueLabel: {
                    Text("\(balance)")
                        .font(.subheadline)
                }
                .gaugeStyle(
                    CircularGaugeStyle(
                        tint: Gradient(
                            colors: [
                                Settings.shared.consumedColor,
                                Settings.shared.burnedColor
                            ]
                        )
                    )
                )
            }
                
            default: Text(verbatim: "No support.")
        }
    }

}

extension BalanceCircleGaugeComplicationView {

    private var balance: Int {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var balanceSymbol: String {
        balance > 0 ? "bolt.fill" : balance < 0 ? "fork.knife" : "dot"
    }

}

/// Circular gauge complication for the selected balance mode.
struct BalanceCircleGaugeComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCircleGaugeComplicationView(entry: entry, mode: Mode.graphMode)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
                .healthSnapshotAvailability(isUnavailable: entry.data.isUnavailable)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Gauge (now)") : String("Gauge (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance (gauge)")
                : String("Shows caloric balance at midnight (gauge)")
        )
        .supportedFamilies([.accessoryCircular])
    }

}

extension BalanceCircleGaugeComplication {

    private var kind: String {
        Mode.graphMode == .now ? "Balance.circle.gauge.now" : "Balance.circle.gauge.midnight"
    }

}

#Preview(as: .accessoryCircular) {
    BalanceCircleGaugeComplication<NowComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, balance: .deficit))
}

#Preview(as: .accessoryCircular) {
    BalanceCircleGaugeComplication<MidnightComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, balance: .deficit))
}
