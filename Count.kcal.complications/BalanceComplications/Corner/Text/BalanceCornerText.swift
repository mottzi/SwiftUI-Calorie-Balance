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

struct BalanceCornerTextComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.text.now", provider: HealthDataTimelineProvider())
        { entry in
            BalanceCornerTextContent(entry: entry, mode: .now)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Number (now)"))
        .description(String("Shows current caloric balance with text."))
        .supportedFamilies([.accessoryCorner])
    }
}


#Preview(as: .accessoryCorner)
{
    BalanceCornerTextComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
