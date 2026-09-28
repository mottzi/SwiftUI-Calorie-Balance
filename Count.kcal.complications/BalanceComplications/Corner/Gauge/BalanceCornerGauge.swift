import SwiftUI
import WidgetKit

/// Corner gauge for the selected calorie balance mode.
struct BalanceCornerGaugeContent: View {

    @Environment(\.widgetFamily) private var family

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    private var range: ClosedRange<CGFloat> {
        -1.6 * CGFloat(Settings.shared.balanceGoal) ... 1.6 * CGFloat(Settings.shared.balanceGoal)
    }

    var body: some View {
        switch family {
            case .accessoryCorner:
                Text("\(balance)")
                    .widgetCurvesContent()
                    .widgetLabel {
                        Gauge(
                            value: CGFloat(balance).clamped(to: range),
                            in: range,
                            label: { Text(verbatim: "") }
                        )
                        .tint(Gradient(colors: [Settings.shared.consumedColor, Settings.shared.burnedColor]))
                    }

            default:
                if mode == .now {
                    Text(verbatim: "No support.")
                } else {
                    EmptyView()
                }
        }
    }

    private var balance: Int {
        switch mode {
            case .now: entry.data.balanceNow
            case .midnight: entry.data.balanceMidnight
        }
    }

}

/// Corner gauge complication for the selected balance mode.
struct BalanceCornerGaugeComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCornerGaugeContent(entry: entry, mode: Mode.graphMode)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Gauge (now)") : String("Gauge (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance and a gauge.")
                : String("Shows caloric balance at midnight (gauge)")
        )
        .supportedFamilies([.accessoryCorner])
    }

    private var kind: String {
        Mode.graphMode == .now ? "Balance.corner.gauge.now" : "Balance.corner.gauge.midnight"
    }

}

#Preview(as: .accessoryCorner)
{
    BalanceCornerGaugeComplication<NowComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .accessoryCorner)
{
    BalanceCornerGaugeComplication<MidnightComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
