import WidgetKit
import SwiftUI

struct BalanceWidgetBar: Widget
{
    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: "BarBalanceGraphWidget",
            provider: HealthDataTimelineProvider())
        { entry in
            BalanceWidgetBarContent(
                entry: entry,
                mode: ModeToggleManager.buttonMode() ? .now : .midnight)
            .containerBackground(Color("BackGroundColor"), for: .widget)
            .environmentObject(AppSettings)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows a bar graph of your calorie balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Calorie bar widget content for the selected balance mode.
private struct BalanceWidgetBarContent: View
{

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.widgetFamily) var family: WidgetFamily
    
    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    private var balance: Int
    {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var burnedTotal: Int
    {
        if mode == .now
        {
            return entry.data.burnedActive + entry.data.burnedPassive
        }
        return entry.data.burnedActiveMidnight + entry.data.burnedPassive + entry.data.burnedPassiveRemaining
    }

    private var burnedPassiveTotal: Int
    {
        mode == .now ? entry.data.burnedPassive : entry.data.burnedPassive + entry.data.burnedPassiveRemaining
    }
    
    private var goalReached: Bool
    {
        if AppSettings.weightGoal == .lose
        {
            return balance >= Int(AppSettings.balanceGoal)
        }
        else
        {
            return balance <= -Int(AppSettings.balanceGoal)
        }
    }
    
    var body: some View
    {
        switch family
        {
            case .systemSmall:
            ZStack(alignment: .top)
            {
                HStack(alignment: .top, spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    modeButton
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 7.0)
                        .padding(.horizontal, -2)

                    barGraph(for: .systemSmall)
                }
                .padding(10)
                .padding(.top, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                
            case .systemMedium:
            ZStack(alignment: mode == .now ? .topLeading : .top)
            {
                HStack(alignment: .top, spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    modeButton
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 5.0)

                    barGraph(for: .systemMedium)
                }
                .padding(10)
                
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            default:
            Text(verbatim: "Widget size not supported")
        }
    }

    @ViewBuilder
    private func barGraph(for family: WidgetFamily) -> some View
    {
        if mode == .now
        {
            BarBalanceGraph(context: .widget(family))
                .environment(HealthInterface(entry.data))
                .frame(height: 44)
                .padding(.horizontal, family == .systemSmall ? 3 : 20)
                .padding(.bottom, 4)
                .fontDesign(.rounded)
        }
        else
        {
            BarBalanceGraphMidnight(
                context: .widget(family),
                burnedActive: entry.data.burnedActiveMidnight,
                burnedPassive: entry.data.burnedPassive,
                burnedPassive7: entry.data.burnedPassive7,
                consumed: entry.data.consumed,
                consumedColor: AppSettings.consumedColor,
                burnedColor: AppSettings.burnedColor
            )
            .frame(height: 44)
            .padding(.bottom, 4)
            .padding(.horizontal, family == .systemSmall ? 3 : 20)
            .fontDesign(.rounded)
        }
    }
        
    var modeButton: some View
    {
        Button(intent: ToggleViewModeIntent(), label:
        {
            ZStack(alignment: .topTrailing)
            {
                // button hit-box
                Color.clear
                    .frame(width: 50, height: 35)
                
                HStack
                {
                    // button label
                    Image(systemName: mode == .now ? "sun.min.fill" : "moon.fill")
                        .foregroundColor(Color("SecondaryTextColor"))
                        .font(.caption)
                        .fontWeight(.thin)
                        .padding(.trailing, 12)
                        .padding(.leading, 10)
                        .padding(.top, 3)
                        .background
                        {
                            if scheme == .dark
                            {
                                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 20, bottomTrailingRadius: 0, topTrailingRadius: 20, style: .circular)
                                    .fill(Color("BackGroundColor").gradient)
                            }
                        }
                        .opacity(0.8)
                }
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
    }
    
    var timeReloadButton: some View
    {
        Button(intent: TestAppIntent())
        {
            ZStack(alignment: .topLeading)
            {
                Color.clear
                    .frame(width: 50, height: 35)
                
                Text(verbatim: "\(entry.date.shortTime)")
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .font(.caption)
                    .fontWeight(.thin)
                    .padding(.leading, 12)
                    .padding(.trailing, 9)
                    .padding(.top, 2)
                    .background
                    {
                        if scheme == .dark
                        {
                            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 20, topTrailingRadius: 0, style: .continuous)
                                .fill(Color("BackGroundColor").gradient)
                        }
                    }
                    .opacity(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var topGraph: some View
    {
        if family == .systemMedium
        {
            HStack(alignment: .lastTextBaseline)
            {
                Spacer()

                BalanceDataLabelExtra(
                    icon: "bolt.fill",
                    color: AppSettings.burnedColor,
                    label: String(localized: "Burned"),
                    dataMain: burnedTotal,
                    dataTop: entry.data.burnedActive,
                    dataBottom: burnedPassiveTotal)
                .frame(minWidth: 70)

                Spacer()
                Divider().frame(height: 60)
                Spacer()
                
                BalanceDataLabelSimple(
                    icon: "fork.knife",
                    color: AppSettings.consumedColor,
                    label: String(localized: "Eaten"),
                    data: entry.data.consumed)
                .frame(minWidth: 70)

                Spacer()
                Divider().frame(height: 60)
                Spacer()
                
                topGraphBalanceColumn
                    .frame(minWidth: 70)
                
                Spacer()
            }
            .padding(.horizontal, 10)
        }
        else
        {
            HStack(alignment: .lastTextBaseline)
            {
                VStack
                {
                    Image(systemName: "bolt.fill")
                        .font(.subheadline)
                        .foregroundColor(AppSettings.burnedColor)
                        .brightness(scheme == .dark ? 0.15 : 0)
                    
                    Text("\(burnedTotal)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                    
                    Text(String(localized: "Burned"))
                        .foregroundColor(Color("SecondaryTextColor"))
                        .font(.caption)
                        .fontWeight(.light)
                }
                
                Spacer()
                
                VStack
                {
                    Image(systemName: "fork.knife")
                        .font(.subheadline)
                        .foregroundColor(AppSettings.consumedColor)
                        .brightness(scheme == .dark ? 0.15 : 0)

                    Text("\(entry.data.consumed)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                    
                    Text(String(localized: "Eaten"))
                        .foregroundColor(Color("SecondaryTextColor"))
                        .font(.caption)
                        .fontWeight(.light)
                }
            }
            .padding(.horizontal, 10)
            .fontDesign(.rounded)
        }
    }
    
    var topGraphBalanceColumn: some View
    {
        VStack(spacing: 0)
        {
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .padding(.bottom, 4)
            
            if mode == .now
            {
                Text("\(abs(balance))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
            }
            else
            {
                Text("\(abs(balance))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
            }
            
            Text(String(localized: balance > 0 ? "Deficit" : "Surplus"))
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(Color("TextColor"))
        }
        .fontDesign(.rounded)
    }

}

#Preview(as: .systemMedium)
{
    BalanceWidgetBar()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
