import SwiftUI
import WidgetKit

struct BalanceCornerTextNowMidnightComplicationView : View {

    @Environment(\.widgetFamily) var family

    var entry: HealthDataTimelineProvider.Entry

    var body: some View {
        switch family {
            case .accessoryCorner: do {
                Text(verbatim: "\(entry.data.balanceNow)")
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text(verbatim: "\(entry.data.balanceMidnight)")
                            .foregroundStyle(balanceColor)
                    }
            }
                
            default: EmptyView()
        }
    }

}

extension BalanceCornerTextNowMidnightComplicationView {

    var balanceColor: Color {
        var c = entry.data.balanceMidnight > 0
            ? Settings.shared.burnedColor
            : entry.data.balanceMidnight < 0
                ? Settings.shared.consumedColor
                : Color.white

        c = c.brighten(0.6)

        return c
    }


}

struct BalanceCornerTextNowMidnightComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Balance.text.now.midnight", provider: HealthDataTimelineProvider()) { entry in
            BalanceCornerTextNowMidnightComplicationView(entry: entry)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(String("Number (both)"))
        .description(String("Shows current caloric balance and at midnight with text."))
        .supportedFamilies([.accessoryCorner])
    }

}


#Preview(as: .accessoryCorner) {
    BalanceCornerTextNowMidnightComplication()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
