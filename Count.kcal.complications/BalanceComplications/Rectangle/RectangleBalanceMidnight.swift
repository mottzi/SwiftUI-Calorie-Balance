import SwiftUI
import WidgetKit

struct RectangleBalanceMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
    var balanceSymbol: String
    {
        entry.data.balanceMidnight >= 0 ? "bolt.fill" : "fork.knife"
    }
    
    var burnedTotal: Int
    {
        (Settings.shared.dataSource == Settings.DataSources.custom ? entry.data.burnedActive7 : entry.data.burnedActive) + entry.data.burnedPassive + entry.data.burnedPassiveRemaining
    }
    
    var body: some View
    {
        switch family
        {
            case .accessoryRectangular: do
            {
                GeometryReader
                { geo in
                    HStack(spacing: 0)
                    {
                        CircleBalanceGraphWatch(mode: .midnight, rendering: renderingMode, context: .circleFuller, cutout: 0.22)
                            .environment(HealthInterface(entry.data))
                            .environmentObject(Settings.shared)
                            .frame(width: geo.size.height * 0.8)
                            .overlay
                            {
                                Image(systemName: balanceSymbol)
                                    .font(.system(size: 12))
                                    .offset(y: 20)
                            }
                            .padding(.leading)
                            .offset(y: 3)
                            .widgetAccentable()

                        Spacer(minLength: 2)
                        
                        VStack(alignment: .leading, spacing: 0)
                        {
                            HStack(spacing: 0)
                            {
                                Image(systemName: "bolt.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Settings.shared.burnedColor.brighten(0.3).gradient)
                                
                                HStack(alignment: .lastTextBaseline, spacing: 2)
                                {
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
                                         
                            HStack(spacing: 0)
                            {
                                Image(systemName: "fork.knife")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Settings.shared.consumedColor.brighten(0.2).gradient)

                                HStack(alignment: .lastTextBaseline, spacing: 2)
                                {
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
                            
                            HStack(spacing: 0)
                            {
                                Image(systemName: "equal")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .frame(width: 16, height: 16)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                HStack(alignment: .lastTextBaseline, spacing: 2)
                                {
                                    Text("\(entry.data.balanceMidnight)")
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
                        .fixedSize()
                        
                        Spacer(minLength: 2)
                    }
                }
            }
                
            default: EmptyView()
        }
    }
}

struct RectangleBalanceMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.midnight", provider: HealthDataTimelineProvider())
        { entry in
            let c = entry.data.balanceMidnight >= 0 ? Settings.shared.burnedColor : Settings.shared.consumedColor
        
            RectangleBalanceMidnightComplicationView(entry: entry)
                .containerBackground(c.brighten(0.1).gradient, for: .widget)
        }
        .configurationDisplayName("Balance (midnight)")
        .description("Shows caloric balance at midnight.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular)
{
    RectangleBalanceMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
