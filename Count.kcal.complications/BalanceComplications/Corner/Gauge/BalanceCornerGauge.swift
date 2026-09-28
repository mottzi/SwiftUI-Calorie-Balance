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

struct BalanceCornerGaugeComplication: Widget
{
    var body: some WidgetConfiguration 
    {
        StaticConfiguration(kind: "Balance.corner.gauge.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerGaugeContent(entry: entry, mode: .now)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Gauge (now)"))
        .description(String("Shows current caloric balance and a gauge."))
        .supportedFamilies([.accessoryCorner])
    }
}


#Preview(as: .accessoryCorner)
{
    BalanceCornerGaugeComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
