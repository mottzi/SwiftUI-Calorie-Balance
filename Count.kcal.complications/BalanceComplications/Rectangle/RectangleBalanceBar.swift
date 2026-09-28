import SwiftUI
import WidgetKit

/// Rectangular energy totals and balance bar for one mode.
struct RectangleBalanceBarComplicationView : View
{
    @Environment(\.widgetFamily) var family

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    private var burnedTotal: Int
    {
        switch mode
        {
            case .now: entry.data.now.burned
            case .midnight: entry.data.midnight.burned
        }
    }

    private var balance: Int
    {
        switch mode
        {
            case .now: entry.data.balanceNow
            case .midnight: entry.data.balanceMidnight
        }
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

                            Text("\(balance)")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                    }
                    .compositingGroup()
                    .minimumScaleFactor(0.5)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .padding(.trailing, 4)
                    
                    BarBalanceGraphWatch(mode: mode)
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

struct RectangleBalanceBarComplication: Widget
{
    var body: some WidgetConfiguration
    {
        StaticConfiguration(kind: "Balance.rect.bar.now", provider: HealthDataTimelineProvider())
        { entry in        
            RectangleBalanceBarComplicationView(entry: entry, mode: .now)
                .containerBackground(Color(red: 30/255, green: 30/255, blue: 30/255), for: .widget)

        }
        .configurationDisplayName(String("Bar (now)"))
        .description(String("Shows current caloric balance."))
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}


#Preview(as: .accessoryRectangular)
{
    RectangleBalanceBarComplication()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
