import WidgetKit
import SwiftUI

struct HealthDataEntry: TimelineEntry
{
    let date: Date
    let data: HealthData
}

struct ToggleWidgetProvider: TimelineProvider
{
    func placeholder(in context: Context) -> HealthDataEntry 
    {
        HealthDataEntry(date: .now, data: HealthData.example(for: .now))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HealthDataEntry) -> Void) 
    {
        completion(HealthDataEntry(date: .now, data: HealthData.example(for: .now)))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthDataEntry>) -> Void)
    {
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!

        Task
        {
            let timeline = Timeline(
                entries: [HealthDataEntry(date: .now, data: try! await asyncFetchData())],
                policy: .after(nextUpdateDate)
            )
            
            completion(timeline)
        }
    }
}

struct BalanceWidgetCircle: Widget
{
    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: "CircleBalanceGraphWidget",
            provider: ToggleWidgetProvider())
            { entry in
                if ModeToggleManager.buttonMode() == false
                {
                    BalanceWidgetCircleMidnight(entry: entry)
                        .environmentObject(AppSettings)
                        .containerBackground(Color("BackGroundColor"), for: .widget)
                }
                else
                {
                    BalanceWidgetCircleNow(entry: entry)
                        .environmentObject(AppSettings)
                        .containerBackground(Color("BackGroundColor"), for: .widget)
                }
            }
            .contentMarginsDisabled()
            .configurationDisplayName("Calorie Dashboard")
            .description("Shows a circular graph of your calorie balance.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BalanceWidgetCircleMidnight: View
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
            ZStack(alignment: .center)
            {
                HStack(spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    midnightLabel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                topGraphBalanceColumn
                    .padding(.top, 5)
                
                GeometryReader
                { geo in
                    HStack(spacing: 20)
                    {
                        HStack(spacing: 2)
                        {
                            Text("\(getActiveBurnedCalories() + entry.data.burnedPassive + entry.data.burnedPassiveRemaining)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))

                            Image(systemName: "bolt.fill")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.burnedColor)
                                .brightness(level: .secondary)
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .trailing)
                        
                        HStack(spacing: 2)
                        {
                            Image(systemName: "fork.knife")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.consumedColor)
                                .brightness(level: .secondary)

                            Text("\(entry.data.consumed)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .leading)
                    }
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
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
                
                topGraph
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
                // button hit-box
                Color.clear
                    .frame(width: 50, height: 35)
                
                // button label
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
    
    var topGraph: some View
    {
        HStack(spacing: 0)
        {
            VStack(alignment: .leading, spacing: 16)
            {
                HStack(spacing: 14)
                {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.burnedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(entry.data.balanceMidnight > 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(entry.data.balanceMidnight > 0 ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && entry.data.balanceMidnight > 0 ? 1.5 : 1))
                                .padding(-8)
                                .brightness(level: .secondary)
                        }
                        .padding(8)

                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(getActiveBurnedCalories() + entry.data.burnedPassive + entry.data.burnedPassiveRemaining)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }
                        
                        Text(String(localized: "Burned"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
                             
                HStack(spacing: 14)
                {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.consumedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(entry.data.balanceMidnight < 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(entry.data.balanceMidnight < 0 ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && entry.data.balanceMidnight < 0 ? 1.5 : 1))
                                .brightness(level: .secondary)
                                .padding(-8)

                        }
                        .padding(8)
                    
                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(entry.data.consumed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }

                        Text(String(localized: "Eaten"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
            }
            .fontDesign(.rounded)
            .offset(y: -4)
            .fixedSize()
                
            Spacer()
            
            topGraphBalanceColumn
        }
        .padding(.top, 13)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
    
    var topGraphBalanceColumn: some View
    {
        ZStack
        {
            CircleBalanceGraph(mode: .midnight)
                .frame(width: 130, height: 130)
                .environment(HealthInterface(entry.data))
                .brightness(-0.05)
            
            VStack(spacing: 0)
            {
                Text("\(abs(entry.data.balanceMidnight))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(entry.data.balanceMidnight))))
                
                Text(entry.data.balanceMidnight > 0 ? String(localized: "Deficit") : entry.data.balanceMidnight == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
            }
            .fontDesign(.rounded)
            
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40)
                .transaction { $0.animation = .none }
        }
    }
}
struct BalanceWidgetCircleNow: View
{
    @Environment(\.colorScheme) var scheme: ColorScheme
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
            ZStack(alignment: .center)
            {
                HStack(spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    midnightLabel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                topGraphBalanceColumn
                    .padding(.top, 5)
                
                GeometryReader
                { geo in
                    HStack(spacing: 20)
                    {
                        HStack(spacing: 2)
                        {
                            Text("\(entry.data.burnedActive + entry.data.burnedPassive)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))

                            Image(systemName: "bolt.fill")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.burnedColor)
                                .brightness(level: .secondary)
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .trailing)
                        
                        HStack(spacing: 2)
                        {
                            Image(systemName: "fork.knife")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.consumedColor)
                                .brightness(level: .secondary)

                            Text("\(entry.data.consumed)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .leading)
                    }
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
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
                
                topGraph
            }

            default:
            Text("Widget size not supported")
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
                // button hit-box
                Color.clear
                    .frame(width: 50, height: 35)
                
                // button label
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
    
    var topGraph: some View
    {
        HStack(spacing: 0)
        {
            VStack(alignment: .leading, spacing: 16)
            {
                HStack(spacing: 14)
                {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.burnedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(entry.data.balanceNow > 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(entry.data.balanceNow > 0 ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && entry.data.balanceNow > 0 ? 1.5 : 1))
                                .padding(-8)
                                .brightness(level: .secondary)
                        }
                        .padding(8)

                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(entry.data.burnedActive + entry.data.burnedPassive)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }
                        
                        Text(String(localized: "Burned"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
                             
                HStack(spacing: 14)
                {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.consumedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(entry.data.balanceNow < 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(entry.data.balanceNow < 0 ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && entry.data.balanceNow < 0 ? 1.5 : 1))
                                .brightness(level: .secondary)
                                .padding(-8)
                        }
                        .padding(8)
                    
                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(entry.data.consumed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }

                        Text(String(localized: "Eaten"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
            }
            .fontDesign(.rounded)
            .offset(y: -4)
            .fixedSize()
                
            Spacer()
            
            topGraphBalanceColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 13)
        .padding(.horizontal, 30)
    }
    
    var topGraphBalanceColumn: some View
    {
        ZStack
        {
            CircleBalanceGraph(mode: .now)
                .frame(width: 130, height: 130)
                .environment(HealthInterface(entry.data))
                .brightness(-0.05)
            
            VStack(spacing: 0)
            {
                Text("\(abs(entry.data.balanceNow))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(entry.data.balanceNow))))
                
                Text(entry.data.balanceNow > 0 ? String(localized: "Deficit") : entry.data.balanceNow == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
            }
            .fontDesign(.rounded)
        
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40)
                .transaction { $0.animation = .none }
        }
    }
}

#Preview(as: .systemSmall)
{
    BalanceWidgetCircle()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
