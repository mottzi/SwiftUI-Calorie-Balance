import SwiftUI
import WidgetKit

struct RectangleBalanceBarMidnightComplicationView : View
{
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode

    var entry: HealthDataTimelineProvider.Entry
    
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
                VStack
                {
                    HStack
                    {
                        HStack(spacing: 0)
                        {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .fontWeight(.semibold)
                                .foregroundStyle(Settings.shared.burnedColor.brighten(0.1).gradient)
                            
                            Text("\(burnedTotal)")
                                .fontWeight(.medium)
                                .foregroundStyle(Settings.shared.burnedColor.brighten(0.3))
                        }
                        
                        HStack(spacing: 2)
                        {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 11))
                                .fontWeight(.semibold)
                                .foregroundStyle(Settings.shared.consumedColor.brighten(0.1).gradient)
                            
                            Text("\(entry.data.consumed)")
                                .fontWeight(.medium)
                                .foregroundStyle(Settings.shared.consumedColor.brighten(0.3))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 0)
                        {
                            Image(systemName: "equal")
                                .font(.system(size: 14))
                                .fontWeight(.regular)
                                .foregroundStyle(.primary)
                                .offset(y: 1)

                            HStack(alignment: .lastTextBaseline, spacing: 2)
                            {
                                Text("\(entry.data.balanceMidnight)")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .padding(.trailing, 4)
                    
                    BarBalanceGraphWatchMidnight()
                        .environmentObject(Settings.shared)
                        .environment(HealthInterface(entry.data))
                        .padding(.bottom)
                }
                .padding(.horizontal)
            }
                
            default: EmptyView()
        }
    }
}

struct RectangleBalanceBarMidnightComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.bar.midnight", provider: HealthDataTimelineProvider())
        { entry in
            RectangleBalanceBarMidnightComplicationView(entry: entry)
                .containerBackground(Color(red: 30/255, green: 30/255, blue: 30/255), for: .widget)

        }
        .configurationDisplayName(String("Bar (midnight)"))
        .description(String("Shows caloric balance at midnight."))
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular)
{
    RectangleBalanceBarMidnightComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

