import SwiftUI
import WidgetKit

/// Corner balance amount and status for the selected mode.
struct BalanceCornerTextContent: View {

    @Environment(\.widgetFamily) private var family

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    var body: some View {
        switch family {
            case .accessoryCorner:
                Text("\(abs(balance))")
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text(balance > 0 ? "Deficit" : balance == 0 ? "Balance" : "Surplus")
                            .foregroundStyle(balanceColor)
                    }

            default: EmptyView()
        }
    }

    private var balance: Int {
        switch mode {
            case .now: entry.data.balanceNow
            case .midnight: entry.data.balanceMidnight
        }
    }

    private var balanceColor: Color {
        let color = balance > 0 ? Settings.shared.burnedColor : balance < 0 ? Settings.shared.consumedColor : Color.white
        return color.brighten(0.6)
    }

}

/// Corner balance text complication for the selected mode.
struct BalanceCornerTextComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            BalanceCornerTextContent(entry: entry, mode: Mode.graphMode)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Number (now)") : String("Number (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance with text.")
                : String("Shows caloric balance at midnight with text.")
        )
        .supportedFamilies([.accessoryCorner])
    }

    private var kind: String {
        Mode.graphMode == .now ? "Balance.text.now" : "Balance.text.midnight"
    }

}

#Preview(as: .accessoryCorner)
{
    BalanceCornerTextComplication<NowComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .accessoryCorner)
{
    BalanceCornerTextComplication<MidnightComplicationMode>()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
