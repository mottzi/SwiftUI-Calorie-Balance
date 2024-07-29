import SwiftUI
import WidgetKit

struct RectangleBalanceBarComplicationView : View
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
                            
                            Text("\(entry.data.burnedActive + entry.data.burnedPassive)")
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
                                Text("\(entry.data.balanceNow)")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .padding(.trailing, 4)
                    
                    BarBalanceGraphWatch()
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
            RectangleBalanceBarComplicationView(entry: entry)
                .containerBackground(Color(red: 30/255, green: 30/255, blue: 30/255), for: .widget)

        }
        .configurationDisplayName("Bar (now)")
//        .description("")
        .description("Shows current caloric balance.")
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

