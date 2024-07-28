import SwiftUI
import WidgetKit

struct RectangleBalanceComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry

    var balanceSymbol: String
    {
        entry.data.balanceNow > 0 ? "bolt.fill" : entry.data.balanceNow < 0 ? "fork.knife" : "dot"
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
                        CircleBalanceGraphWatch(mode: .now, rendering: renderingMode, context: .circleFuller, cutout: 0.22)
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

                        Spacer()
                        
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
                                    Text("\(entry.data.burnedActive + entry.data.burnedPassive)")
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
                                    Text("\(entry.data.balanceNow)")
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
                        
                        Spacer()
                    }
                }
            }
                
            default: EmptyView()
        }
    }
}

struct RectangleBalanceComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.now", provider: HealthDataTimelineProvider())
        { entry in
            let c = entry.data.balanceNow >= 0 ? Settings.shared.burnedColor : Settings.shared.consumedColor
        
            RectangleBalanceComplicationView(entry: entry)
                .containerBackground(c.brighten(0.1).gradient, for: .widget)
        }
        .configurationDisplayName("Balance (now)")
        .description("Shows current caloric balance.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}


#Preview(as: .accessoryRectangular)
{
    RectangleBalanceComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

