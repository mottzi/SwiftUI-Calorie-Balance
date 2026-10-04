import SwiftUI
import WidgetKit

/// Rectangular balance circle and energy totals for one mode.
struct RectangleBalanceComplicationView : View {

    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    var body: some View {
        switch family {
            case .accessoryRectangular: do {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        CircleBalanceGraphWatch(mode: mode, rendering: renderingMode, context: .circleFuller, cutout: 0.22)
                            .environment(HealthInterface(entry.data))
                            .environmentObject(Settings.shared)
                            .frame(width: geo.size.height * 0.8)
                            .overlay {
                                Image(systemName: balanceSymbol)
                                    .font(.system(size: 12))
                                    .offset(y: 20)
                            }
                            .padding(.leading)
                            .offset(y: 3)
                            .widgetAccentable()

                        Spacer(minLength: mode == .midnight ? 2 : nil)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Image(systemName: "bolt.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Settings.shared.burnedColor.brighten(0.3).gradient)
                                
                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("\(burnedTotal)")
                                        .fontWeight(.medium)
                                        .foregroundStyle(Settings.shared.burnedColor.brighten(0.45))
                                        .frame(minWidth: 50, alignment: .trailing)
                                    
                                    Text(verbatim: Settings.shared.energyUnit == .kJ ? "kJ" : "kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.regular)
                                }
                            }
                                         
                            HStack(spacing: 0) {
                                Image(systemName: "fork.knife")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Settings.shared.consumedColor.brighten(0.2).gradient)

                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("\(entry.data.consumed)")
                                        .fontWeight(.medium)
                                        .foregroundStyle(Settings.shared.consumedColor.brighten(0.3))
                                        .frame(minWidth: 50, alignment: .trailing)
                                    
                                    Text(verbatim: Settings.shared.energyUnit == .kJ ? "kJ" : "kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.regular)
                                }
                            }
                            
                            Divider()
                                .background(.primary.opacity(0.42))
                                .padding(.vertical, 1)
                                .padding(.top, 1)
                            
                            HStack(spacing: 0) {
                                Image(systemName: "equal")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("\(balance)")
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .frame(minWidth: 50, alignment: .trailing)
                                    
                                    Text(verbatim: Settings.shared.energyUnit == .kJ ? "kJ" : "kcal")
                                        .font(.caption)
                                        .fontWeight(.regular)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.trailing, 2)
                        .compositingGroup()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .fixedSize()
                        
                        Spacer(minLength: mode == .midnight ? 2 : nil)
                    }
                }
            }
                
            default: EmptyView()
        }
    }

}

extension RectangleBalanceComplicationView {

    private var balanceSymbol: String {
        switch mode {
            case .now: entry.data.balanceNow > 0 ? "bolt.fill" : entry.data.balanceNow < 0 ? "fork.knife" : "dot"
            case .midnight: entry.data.balanceMidnight >= 0 ? "bolt.fill" : "fork.knife"
        }
    }

    private var burnedTotal: Int {
        switch mode {
            case .now: entry.data.now.burned
            case .midnight: entry.data.midnight.burned
        }
    }

    private var balance: Int {
        switch mode {
            case .now: entry.data.balanceNow
            case .midnight: entry.data.balanceMidnight
        }
    }


}

/// Rectangular balance circle complication for the selected mode.
struct RectangleBalanceComplication<Mode: BalanceComplicationMode>: Widget {

    var body: some WidgetConfiguration {

        StaticConfiguration(kind: kind, provider: HealthDataTimelineProvider()) { entry in
            let balance = Mode.graphMode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
            let color = balance >= 0 ? Settings.shared.burnedColor : Settings.shared.consumedColor

            RectangleBalanceComplicationView(entry: entry, mode: Mode.graphMode)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
                .containerBackground(color.brighten(0.1).gradient, for: .widget)
        }
        .configurationDisplayName(Mode.graphMode == .now ? String("Circle (now)") : String("Circle (midnight)"))
        .description(
            Mode.graphMode == .now
                ? String("Shows current caloric balance.")
                : String("Shows caloric balance at midnight.")
        )
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }

}

extension RectangleBalanceComplication {

    private var kind: String {
        Mode.graphMode == .now ? "Balance.rect.now" : "Balance.rect.midnight"
    }

}

#Preview(as: .accessoryRectangular) {
    RectangleBalanceComplication<NowComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, random: true))
}

#Preview(as: .accessoryRectangular) {
    RectangleBalanceComplication<MidnightComplicationMode>()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
