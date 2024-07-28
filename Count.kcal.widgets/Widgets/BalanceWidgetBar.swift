import WidgetKit
import SwiftUI

struct BalanceWidgetBar: Widget
{
    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: "BarBalanceGraphWidget",
            provider: ToggleWidgetProvider())
        { entry in
            if ModeToggleManager.buttonMode() == false
            {
                BalanceWidgetBarMidnight(entry: entry)
                    .containerBackground(Color("BackGroundColor"), for: .widget)
                    .environmentObject(AppSettings)
            }
            else
            {
                BalanceWidgetBarNow(entry: entry)
                    .containerBackground(Color("BackGroundColor"), for: .widget)
                    .environmentObject(AppSettings)
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows a bar graph of your calorie balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BalanceWidgetBarMidnight: View
{
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.widgetFamily) var family: WidgetFamily
    
    var entry: ToggleWidgetProvider.Entry
    
    private var goalReached: Bool
    {
        if AppSettings.weightGoal == .lose
        {
            return entry.data.balanceMidnight >= Int(AppSettings.balanceGoal)
        }
        else
        {
            return entry.data.balanceMidnight <= -Int(AppSettings.balanceGoal)
        }
    }
    
    func getActiveBurnedCalories() -> Int
    {
        if AppSettings.dataSource == .custom
        {
            return entry.data.burnedActive7
        }
        else
        {
            return entry.data.burnedActive
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
                    
                    midnightLabel
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 7.0)
                        .padding(.horizontal, -2)

                    BarBalanceGraphMidnight(context: .widget(.systemSmall), burnedActive: getActiveBurnedCalories(), burnedPassive: entry.data.burnedPassive, burnedPassive7: entry.data.burnedPassive7, consumed: entry.data.consumed, consumedColor: AppSettings.consumedColor, burnedColor: AppSettings.burnedColor)
                        .frame(height: 44)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 3)
                        .fontDesign(.rounded)
                }
                .padding(10)
                .padding(.top, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                
            case .systemMedium:
            ZStack(alignment: .top)
            {
                HStack(alignment: .top, spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    midnightLabel
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 5.0)

                    BarBalanceGraphMidnight(context: .widget(.systemMedium), burnedActive: getActiveBurnedCalories(), burnedPassive: entry.data.burnedPassive, burnedPassive7: entry.data.burnedPassive7, consumed: entry.data.consumed, consumedColor: AppSettings.consumedColor, burnedColor: AppSettings.burnedColor)
                        .frame(height: 44)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 20)
                        .fontDesign(.rounded)
                }
                .padding(10)
                
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            default:
            Text(verbatim: "Widget size not supported")
        }
    }
        
    var midnightLabel: some View
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
                    Image(systemName: "moon.fill")
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
                    dataMain: getActiveBurnedCalories() + entry.data.burnedPassive + entry.data.burnedPassiveRemaining,
                    dataTop: entry.data.burnedActive,
                    dataBottom: entry.data.burnedPassive + entry.data.burnedPassiveRemaining)
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
                    
                    Text("\(getActiveBurnedCalories() + entry.data.burnedPassive + entry.data.burnedPassiveRemaining)")
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
                .padding(.bottom, /*goalReached ? 2 : */4)
            
            Text("\(abs(entry.data.balanceMidnight))")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color("TextColor"))
                .contentTransition(.numericText(value: Double(abs(entry.data.balanceMidnight))))
            
            Text(String(localized: entry.data.balanceMidnight > 0 ? "Deficit" : "Surplus"))
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(Color("TextColor"))
        }
        .fontDesign(.rounded)
    }
}

struct BalanceWidgetBarNow: View
{
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.widgetFamily) var family: WidgetFamily
    
    var entry: ToggleWidgetProvider.Entry
    
    private var goalReached: Bool
    {
        // loose weight goal
        if AppSettings.weightGoal == .lose
        {
            return entry.data.balanceNow >= Int(AppSettings.balanceGoal)
        }
        // gain weight goal
        else
        {
            return entry.data.balanceNow <= -Int(AppSettings.balanceGoal)
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
                    
                    midnightLabel
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 7.0)
                        .padding(.horizontal, -2)

                    BarBalanceGraph(context: .widget(.systemSmall))
                        .environment(HealthInterface(entry.data))
                        .frame(height: 44)
                        .padding(.horizontal, 3)
                        .padding(.bottom, 4)
                        .fontDesign(.rounded)
                }
                .padding(10)
                .padding(.top, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                
            case .systemMedium:
            ZStack(alignment: .topLeading)
            {
                HStack(alignment: .top, spacing: 0)
                {                    
                    Spacer()
                    
                    midnightLabel
                }
                
                VStack(spacing: 20)
                {
                    topGraph
                        .offset(y: 5.0)
                    
                    BarBalanceGraph(context: .widget(.systemMedium))
                        .environment(HealthInterface(entry.data))
                        .frame(height: 44)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                        .fontDesign(.rounded)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
        default:
            Text(verbatim: "Widget size not supported")
        }
    }
    
    var midnightLabel: some View
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
                    Image(systemName: "sun.min.fill")
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
                    dataMain: entry.data.burnedActive + entry.data.burnedPassive,
                    dataTop: entry.data.burnedActive,
                    dataBottom: entry.data.burnedPassive)
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

                    Text("\(entry.data.burnedActive + entry.data.burnedPassive)")
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
                .padding(.bottom, /*goalReached ? 2 : */4)
            
            Text("\(abs(entry.data.balanceNow))")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color("TextColor"))
                .contentTransition(.numericText(value: Double(abs(entry.data.balanceNow))))
 
            
            Text(String(localized: entry.data.balanceNow > 0 ? "Deficit" : "Surplus"))
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
